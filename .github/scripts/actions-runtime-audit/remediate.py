#!/usr/bin/env python3
"""Opt-in remediation of verified direct Action references only."""
import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import yaml
from scanner import API, AuditError, REMOTE

WF = re.compile(r"\.github/workflows/[^/]+\.ya?ml$")
LOCAL = re.compile(r"(?:action\.ya?ml|\.github/actions/.+/action\.ya?ml)$")
LINE = re.compile(r"^(?P<prefix>\s*(?:-\s*)?uses:\s*)(?P<quote>['\"]?)(?P<value>[^'\"\s#]+)(?P=quote)(?P<tail>[ \t]*(?:#.*)?)$")
AUTOMATION_BRANCH = "automation/actions-node24"
AUTOMATION_COMMIT_MESSAGE = "ci: migrar Actions legadas para Node.js 24"


def mapping(node):
    if not isinstance(node, yaml.nodes.MappingNode):
        return {}
    return {key.value: value for key, value in node.value if isinstance(key, yaml.nodes.ScalarNode)}


def references(source, path):
    """Only semantic uses entries, with source locations from the YAML parser."""
    root = mapping(yaml.compose(source, Loader=yaml.SafeLoader))
    if WF.fullmatch(path):
        for job in mapping(root.get("jobs")).values():
            fields = mapping(job)
            value = fields.get("uses")
            if isinstance(value, yaml.nodes.ScalarNode):
                yield value.start_mark.line, value.value
            steps = fields.get("steps")
            if isinstance(steps, yaml.nodes.SequenceNode):
                for step in steps.value:
                    value = mapping(step).get("uses")
                    if isinstance(value, yaml.nodes.ScalarNode):
                        yield value.start_mark.line, value.value
    elif LOCAL.fullmatch(path):
        runs = mapping(root.get("runs"))
        runtime = runs.get("using")
        if runtime is None or runtime.value.lower() != "composite":
            return
        steps = runs.get("steps")
        if isinstance(steps, yaml.nodes.SequenceNode):
            for step in steps.value:
                value = mapping(step).get("uses")
                if isinstance(value, yaml.nodes.ScalarNode):
                    yield value.start_mark.line, value.value


def replace_line(line, original, target):
    match = LINE.fullmatch(line.rstrip("\r\n"))
    if match is None or match["value"] != original:
        return None
    tail = match["tail"]
    version = target["version"]
    if "#" in tail:
        if re.match(r"\s*#\s*v\d+(?:\.\d+){0,2}\b", tail, re.I):
            tail = re.sub(r"(?i)(#\s*)v\d+(?:\.\d+){0,2}", lambda m: m[1] + version, tail, count=1)
        else:
            tail = re.sub(r"^(\s*#\s*)", lambda m: m[1] + version + " ", tail, count=1)
    else:
        tail = " # " + version
    newline = "\r\n" if line.endswith("\r\n") else "\n" if line.endswith("\n") else ""
    new_ref = original.split("@", 1)[0] + "@" + target["sha"]
    return match["prefix"] + match["quote"] + new_ref + match["quote"] + tail + newline


def plan_file(source, path, targets, api):
    lines = source.splitlines(keepends=True)
    updates = []
    before = list(references(source, path))
    for index, use in before:
        match = REMOTE.fullmatch(use)
        if match is None:
            continue
        owner, name, subpath, ref = match.groups()
        action = f"{owner}/{name}".lower()
        target = targets.get(action)
        if target is None or subpath or ref.lower() == target["sha"]:
            continue
        manifest = api.manifest(f"{owner}/{name}", "action.yml", ref, optional=True)
        if manifest is None:
            manifest = api.manifest(f"{owner}/{name}", "action.yaml", ref, optional=True)
        if manifest is None or str(manifest[1].get("runs", {}).get("using", "")).lower() not in ("node12", "node16", "node20"):
            continue
        destination = api.manifest(f"{owner}/{name}", "action.yml", target["sha"], optional=True)
        if destination is None:
            destination = api.manifest(f"{owner}/{name}", "action.yaml", target["sha"], optional=True)
        if destination is None or str(destination[1].get("runs", {}).get("using", "")).lower() != "node24":
            raise AuditError("Allowlisted Action destination does not declare node24")
        changed = replace_line(lines[index], use, target)
        if changed is None:
            continue
        lines[index] = changed
        updates.append(dict(file=path, line=index + 1, action=action,
                            old=ref, version=target["version"], sha=target["sha"]))
    revised = "".join(lines)
    if updates:
        after = list(references(revised, path))
        if len(after) != len(before) or [i for i, _ in after] != [i for i, _ in before]:
            raise AuditError("YAML structure changed during rewrite")
        allowed = {update["line"] for update in updates}
        if any(old != new and i + 1 not in allowed
               for (i, old), (_, new) in zip(before, after)):
            raise AuditError("Unexpected YAML reference change")
    return revised, updates


class Writer:
    def __init__(self, token):
        if not token:
            raise AuditError("Write-enabled GitHub App token is required")
        self.token = token

    def post(self, path, data):
        if not path.startswith("/") or path.startswith("//"):
            raise AuditError("Invalid GitHub API path")
        request = urllib.request.Request(
            "https://api.github.com" + path,
            data=json.dumps(data).encode("utf-8"),
            headers={"Authorization": "Bearer " + self.token,
                     "Accept": "application/vnd.github+json",
                     "Content-Type": "application/json",
                     "X-GitHub-Api-Version": "2022-11-28",
                     "User-Agent": "actions-runtime-remediator"}, method="POST")
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                result = json.load(response)
            if path == "/graphql" and isinstance(result, dict) and result.get("errors"):
                raise AuditError("GitHub GraphQL mutation rejected")
            return result
        except urllib.error.HTTPError as error:
            raise AuditError(f"GitHub write rejected (HTTP {error.code})") from error
        except urllib.error.URLError as error:
            raise AuditError("GitHub write API unavailable") from error


def automation_branch_is_owned(api, repository, branch_ref):
    if not isinstance(branch_ref, dict):
        return False
    sha = branch_ref.get("object", {}).get("sha")
    if not isinstance(sha, str):
        return False
    commit = api.get(f"/repos/{repository}/git/commits/{sha}")
    return (isinstance(commit, dict)
            and commit.get("message") == AUTOMATION_COMMIT_MESSAGE
            and isinstance(commit.get("parents"), list)
            and len(commit["parents"]) == 1)


def remediate(api, writer, owner, report, policy):
    targets = policy["auto_fixes"]
    for action, target in targets.items():
        if not re.fullmatch(r"[a-z0-9_.-]+/[a-z0-9_.-]+", action):
            raise AuditError("Invalid Action allowlist")
        if not re.fullmatch(r"[a-f0-9]{40}", target["sha"]) or not re.fullmatch(r"v\d+\.\d+\.\d+", target["version"]):
            raise AuditError("Invalid immutable Action target")
    installed = {r["full_name"]: r for r in api.repositories(owner)
                 if r.get("owner", {}).get("login", "").lower() == owner.lower()
                 and not r.get("private") and r.get("visibility", "public") == "public"
                 and not r.get("archived") and not r.get("fork")}
    desired = {item["repository"] for item in report.get("findings", [])
               if isinstance(item, dict) and isinstance(item.get("repository"), str)}
    outcomes = []
    for name in sorted(desired & installed.keys()):
        try:
            branch_name = installed[name]["default_branch"]
            if not branch_name:
                raise AuditError("Missing default branch")
            base = api.get(f"/repos/{name}/git/ref/heads/{urllib.parse.quote(branch_name, safe='')}")["object"]["sha"]
            branch = AUTOMATION_BRANCH
            existing = api.get(f"/repos/{name}/pulls?state=open&head={urllib.parse.quote(owner + ':' + branch, safe='')}&per_page=100")
            if existing:
                outcomes.append(dict(repository=name, status="existing_pr", url=existing[0]["html_url"]))
                continue
            branch_ref = api.get(f"/repos/{name}/git/ref/heads/{branch}", optional=True)
            tree = api.tree(name, base)
            if tree.get("truncated"):
                raise AuditError("Truncated repository tree: automatic remediation skipped")
            paths = sorted(item["path"] for item in tree["tree"] if item.get("type") == "blob"
                           and (WF.fullmatch(item.get("path", "")) or LOCAL.fullmatch(item.get("path", ""))))
            files, changes = [], []
            for path in paths:
                value = api.manifest(name, path, base)
                if value is None:
                    raise AuditError("Missing YAML at pinned base commit")
                revised, updates = plan_file(value[0], path, targets, api)
                if updates:
                    files.append(dict(path=path, mode="100644", type="blob", content=revised))
                    changes.extend(updates)
            if not changes:
                outcomes.append(dict(repository=name, status="manual_review",
                                     reason="No eligible direct allowlisted Action references"))
                continue
            if branch_ref and not automation_branch_is_owned(api, name, branch_ref):
                outcomes.append(dict(repository=name, status="existing_branch", branch=branch,
                                     reason="Automation branch exists but is not safely attributable to this automation; manual review required"))
                continue
            parent_tree = api.get(f"/repos/{name}/git/commits/{base}")["tree"]["sha"]
            new_tree = writer.post(f"/repos/{name}/git/trees", dict(base_tree=parent_tree, tree=files))["sha"]
            commit = writer.post(f"/repos/{name}/git/commits",
                                 dict(message=AUTOMATION_COMMIT_MESSAGE,
                                      tree=new_tree, parents=[base]))["sha"]
            if branch_ref:
                before_oid = branch_ref.get("object", {}).get("sha")
                repository_id = installed[name].get("node_id")
                if not isinstance(before_oid, str) or not isinstance(repository_id, str) or not repository_id:
                    raise AuditError("Missing branch or repository identity for compare-and-swap update")
                writer.post("/graphql", {
                    "query": (
                        "mutation UpdateAutomationRef($repositoryId: ID!, $name: GitRefname!, "
                        "$beforeOid: GitObjectID!, $afterOid: GitObjectID!) { "
                        "updateRefs(input: {repositoryId: $repositoryId, refUpdates: [{name: $name, "
                        "beforeOid: $beforeOid, afterOid: $afterOid, force: true}]}) { clientMutationId } }"
                    ),
                    "variables": {
                        "repositoryId": repository_id,
                        "name": "refs/heads/" + branch,
                        "beforeOid": before_oid,
                        "afterOid": commit,
                    },
                })
            else:
                writer.post(f"/repos/{name}/git/refs", dict(ref="refs/heads/" + branch, sha=commit))
            description = "\n".join(f"- {c['file']}:{c['line']} {c['action']}: {c['old']} -> {c['version']} ({c['sha']})"
                                    for c in changes)
            body = ("## Correções propostas\n\n"
                    "Atualização de referências diretas a Actions oficiais, após verificar os manifestos "
                    "das versões originais e de destino. Somente as Actions na allowlist foram modificadas.\n\n" +
                    description +
                    "\n\n## Validação\n\nPR aberto como rascunho para revisão do diff e execução de CI. "
                    "Não foram modificadas Actions próprias em JavaScript, dependências indiretas "
                    "nem referências que não puderam ser verificadas.\n\n"
                    "Origem: auditoria central de runtimes com apply_fixes=true.")
            pr = writer.post(f"/repos/{name}/pulls",
                             dict(head=branch, base=branch_name,
                                  title="ci: migrar Actions legadas para Node.js 24",
                                  body=body, draft=True))
            outcomes.append(dict(repository=name, status="created", url=pr["html_url"], changes=len(changes)))
        except (AuditError, KeyError, ValueError, TypeError, yaml.YAMLError) as error:
            outcomes.append(dict(repository=name, status="error", reason=str(error)))
    return outcomes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--owner", required=True)
    parser.add_argument("--policy", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9-]{1,39}", args.owner):
        raise AuditError("Invalid owner")
    policy = json.loads(args.policy.read_text(encoding="utf-8"))
    report = json.loads(args.report.read_text(encoding="utf-8"))
    results = remediate(API(os.environ.get("GH_TOKEN", "")),
                        Writer(os.environ.get("GH_TOKEN", "")), args.owner, report, policy)
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "remediation.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    lines = ["## Node 24 remediation", ""]
    for result in results:
        lines.append(f"- {result['repository']}: {result['status']}" +
                     (f" ({result['url']})" if result.get("url") else "") +
                     (f" ({result['reason']})" if result.get("reason") else ""))
    summary = "\n".join(lines) + "\n"
    (args.output / "remediation.md").write_text(summary, encoding="utf-8")
    if os.getenv("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as stream:
            stream.write(summary)
    print(summary)
    return 1 if any(r["status"] == "error" for r in results) else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (AuditError, OSError, ValueError, KeyError) as error:
        print(f"Remediation aborted: {error}", file=sys.stderr)
        sys.exit(1)
