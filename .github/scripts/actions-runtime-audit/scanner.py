#!/usr/bin/env python3
"""Read-only audit of Action runtime declarations in public repositories."""
import argparse
import base64
import datetime
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
import yaml

REMOTE = re.compile(r"^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)(?:/(.*))?@([^\s@]+)$")
USES = re.compile(r"^\s*(?:-\s*)?uses:\s*['\"]?([^'\"\s#]+)", re.M)

class AuditError(Exception):
    pass

class API:
    def __init__(self, token):
        if not token:
            raise AuditError("GitHub App token is missing")
        self.token, self.cache = token, {}

    def get(self, path, optional=False):
        if not path.startswith("/") or path.startswith("//"):
            raise AuditError("Only relative GitHub API paths are allowed")
        if path in self.cache:
            return self.cache[path]
        request = urllib.request.Request("https://api.github.com" + path, headers={
            "Authorization": "Bearer " + self.token,
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "actions-runtime-audit"})
        for retry in range(3):
            try:
                with urllib.request.urlopen(request, timeout=25) as response:
                    value = json.load(response)
                self.cache[path] = value
                return value
            except urllib.error.HTTPError as error:
                if optional and error.code == 404:
                    self.cache[path] = None
                    return None
                if error.code in (429, 500, 502, 503, 504) and retry < 2:
                    time.sleep(2 ** retry)
                    continue
                raise AuditError(f"GitHub API returned HTTP {error.code}") from error
            except (urllib.error.URLError, TimeoutError) as error:
                if retry < 2:
                    time.sleep(2 ** retry)
                    continue
                raise AuditError("GitHub API request failed") from error

    def repositories(self, owner):
        repos = []
        for page in range(1, 101):
            data = self.get(f"/installation/repositories?per_page=100&page={page}")
            batch = data.get("repositories") if isinstance(data, dict) else None
            if not isinstance(batch, list):
                raise AuditError("Invalid installation repositories response")
            repos += [repo for repo in batch
                      if repo.get("owner", {}).get("login", "").lower() == owner.lower()]
            if len(batch) < 100:
                return repos
        raise AuditError("Too many repository pages")

    def tree(self, name, ref):
        value = self.get(f"/repos/{name}/git/trees/{urllib.parse.quote(ref, safe='')}?recursive=1")
        if not isinstance(value, dict) or not isinstance(value.get("tree"), list):
            raise AuditError("Invalid repository tree")
        return value

    def manifest(self, name, path, ref, optional=False):
        path = "/".join(urllib.parse.quote(p, safe="") for p in path.split("/"))
        ref = urllib.parse.quote(ref, safe="")
        data = self.get(f"/repos/{name}/contents/{path}?ref={ref}", optional=optional)
        if data is None:
            return None
        if not isinstance(data, dict) or data.get("type") != "file" or data.get("encoding") != "base64":
            raise AuditError("Unsupported manifest response")
        if data.get("size", 0) > 1000000:
            raise AuditError("YAML exceeds the 1 MB limit")
        try:
            source = base64.b64decode(data["content"]).decode("utf-8")
            doc = yaml.safe_load(source)
        except (ValueError, UnicodeError, KeyError, yaml.YAMLError) as error:
            raise AuditError("Invalid YAML") from error
        if not isinstance(doc, dict):
            raise AuditError("YAML root is not a mapping")
        return source, doc

def workflow_uses(doc):
    jobs = doc.get("jobs", {})
    if isinstance(jobs, dict):
        for job in jobs.values():
            if isinstance(job, dict):
                if isinstance(job.get("uses"), str):
                    yield job["uses"]
                steps = job.get("steps", [])
                for step in steps if isinstance(steps, list) else []:
                    if isinstance(step, dict) and isinstance(step.get("uses"), str):
                        yield step["uses"]

def composite_uses(doc):
    runs = doc.get("runs", {})
    if isinstance(runs, dict) and str(runs.get("using", "")).lower() == "composite":
        steps = runs.get("steps", [])
        for step in steps if isinstance(steps, list) else []:
            if isinstance(step, dict) and isinstance(step.get("uses"), str):
                yield step["uses"]

def source_line(source, reference):
    for match in USES.finditer(source):
        if match.group(1) == reference:
            return source.count("\n", 0, match.start()) + 1
    return None

class Scanner:
    def __init__(self, api, policy):
        self.api, self.policy = api, policy
        self.findings, self.unverified = [], []
        self.repositories_scanned, self.files_scanned = 0, 0

    def record(self, repository, path, line, action, code, detail):
        obj = dict(repository=repository, file=path, line=line, action=action)
        if code == "legacy_runtime":
            obj.update(code=code, detail=detail)
            self.findings.append(obj)
        else:
            obj.update(reason=detail)
            self.unverified.append(obj)

    def inspect_use(self, origin, file, ref, source, use, depth=0, ancestry=frozenset()):
        line = source_line(source, use)
        if "$" + "{" in use:
            self.record(origin, file, line, use, "unverified", "Dynamic reference")
            return
        if use.startswith("docker://"):
            self.record(origin, file, line, use, "unverified", "Docker image is out of scope")
            return
        if use.startswith(("./", "$/")):
            repo, target_ref, path = origin, ref, use[2:].rstrip("/")
            if use.startswith("$/") and not path:
                self.record(origin, file, line, use, "unverified", "Self-repository reference without path")
                return
            kind = ("workflow" if path.startswith(".github/workflows/")
                    and path.endswith((".yml", ".yaml")) else "action")
        else:
            match = REMOTE.fullmatch(use)
            if not match:
                self.record(origin, file, line, use, "unverified", "Unsupported reference")
                return
            owner, name, path, target_ref = match.groups()
            repo, path = f"{owner}/{name}", (path or "").rstrip("/")
            kind = "workflow" if path.startswith(".github/workflows/") and path.endswith((".yml", ".yaml")) else "action"
        if path and any(segment in ("", ".", "..") for segment in path.split("/")):
            self.record(origin, file, line, use, "unverified", "Invalid Action path")
            return
        key = (repo, path, target_ref, kind)
        if key in ancestry or depth >= self.policy.get("max_depth", 5):
            self.record(origin, file, line, use, "unverified", "Nested dependency recursion or depth limit")
            return
        candidates = [path] if kind == "workflow" else [
            f"{path}/action.yml" if path else "action.yml",
            f"{path}/action.yaml" if path else "action.yaml"]
        try:
            result = None
            resolved_path = ""
            for candidate in candidates:
                result = self.api.manifest(repo, candidate, target_ref, optional=True)
                if result is not None:
                    resolved_path = candidate
                    break
            if result is None:
                self.record(origin, file, line, use, "unverified", "Manifest not accessible")
                return
            manifest_source, doc = result
            if kind == "workflow":
                for child in workflow_uses(doc):
                    if child.startswith(("./", "$/")):
                        child_repo, child_file, child_ref, child_source = repo, resolved_path, target_ref, manifest_source
                    else:
                        child_repo, child_file, child_ref, child_source = origin, file, ref, source
                    self.inspect_use(child_repo, child_file, child_ref, child_source,
                                     child, depth + 1, ancestry | {key})
                return
            runs = doc.get("runs", {})
            runtime = str(runs.get("using", "")).lower() if isinstance(runs, dict) else ""
            if re.fullmatch(r"node\d+", runtime):
                if runtime in self.policy["legacy_runtimes"]:
                    hint = self.policy.get("recommended_actions", {}).get(repo.lower())
                    recommendation = f"; check {hint} with tests" if hint else "; find a Node 24-compatible release"
                    self.record(origin, file, line, use, "legacy_runtime",
                                f"Manifest declares {runtime}; required {self.policy['required_runtime']}{recommendation}")
                elif runtime != self.policy["required_runtime"]:
                    self.record(origin, file, line, use, "unverified", f"Runtime {runtime} not covered by policy")
            elif runtime == "composite":
                for child in composite_uses(doc):
                    if child.startswith(("./", "$/")):
                        child_repo, child_file, child_ref, child_source = repo, resolved_path, target_ref, manifest_source
                    else:
                        child_repo, child_file, child_ref, child_source = origin, file, ref, source
                    self.inspect_use(child_repo, child_file, child_ref, child_source,
                                     child, depth + 1, ancestry | {key})
            else:
                self.record(origin, file, line, use, "unverified", f"Non-JavaScript or unknown Action runtime: {runtime}")
        except AuditError as error:
            self.record(origin, file, line, use, "unverified", str(error))

    def inspect_repository(self, repository):
        name, branch = repository["full_name"], repository.get("default_branch")
        if not branch:
            self.record(name, "", None, "", "unverified", "No default branch")
            return
        try:
            tree = self.api.tree(name, branch)
        except AuditError as error:
            self.record(name, "", None, "", "unverified", str(error))
            return
        self.repositories_scanned += 1
        if tree.get("truncated"):
            self.record(name, "", None, "", "unverified", "Recursive tree truncated; inspection incomplete")
        files = sorted(entry["path"] for entry in tree["tree"] if entry.get("type") == "blob" and (
            re.fullmatch(r"\.github/workflows/[^/]+\.ya?ml", entry.get("path", "")) or
            re.fullmatch(r"(?:action\.ya?ml|\.github/actions/.+/action\.ya?ml)", entry.get("path", ""))))
        for path in files:
            try:
                result = self.api.manifest(name, path, branch)
                if result is None:
                    raise AuditError("YAML missing")
                source, doc = result
                self.files_scanned += 1
                uses = list(workflow_uses(doc)) if path.startswith(".github/workflows/") else list(composite_uses(doc))
                if path.endswith(("action.yml", "action.yaml")):
                    runs = doc.get("runs", {})
                    runtime = str(runs.get("using", "")).lower() if isinstance(runs, dict) else ""
                    if runtime in self.policy["legacy_runtimes"]:
                        self.record(name, path, None, "local Action", "legacy_runtime",
                                    f"Own Action declares {runtime}; migrate to Node 24")
                for use in uses:
                    self.inspect_use(name, path, branch, source, use)
            except AuditError as error:
                self.record(name, path, None, "", "unverified", str(error))

    def run(self, owner):
        repositories = self.api.repositories(owner)
        private = sum(bool(repo.get("private") or repo.get("visibility") == "private")
                      for repo in repositories)
        archived = sum(bool(repo.get("archived")) and not repo.get("private")
                       for repo in repositories)
        public = sorted((repo for repo in repositories if not repo.get("private")
                         and repo.get("visibility", "public") == "public" and not repo.get("archived")),
                        key=lambda repo: repo["full_name"].lower())
        for repo in public:
            self.inspect_repository(repo)
        return dict(
            generated_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            scope="Active public repositories accessible to the GitHub App",
            repositories_scanned=self.repositories_scanned,
            workflow_and_action_files_scanned=self.files_scanned,
            private_repositories_excluded=private,
            archived_public_repositories_excluded=archived,
            findings=sorted(self.findings, key=lambda f: (f["repository"], f["file"], f["line"] or 0, f["action"])),
            unverified=sorted(self.unverified, key=lambda f: (f["repository"], f["file"], f["line"] or 0, f["action"])))

def markdown(report):
    lines = ["# GitHub Actions runtime audit", "",
             f"Generated UTC: {report['generated_utc']}",
             f"Public repositories scanned: {report['repositories_scanned']}; YAML files: {report['workflow_and_action_files_scanned']}.",
             f"Private repositories excluded: {report['private_repositories_excluded']}; archived public excluded: {report['archived_public_repositories_excluded']}.",
             "", "## Legacy runtimes", ""]
    for finding in report["findings"]:
        lines.append(f"- {finding['repository']} / {finding['file']}:{finding['line']}: {finding['action']}: {finding['detail']}")
    if not report["findings"]:
        lines.append("No legacy runtime found in successfully inspected files.")
    lines += ["", "## Unverified or out-of-scope dependencies", ""]
    for finding in report["unverified"]:
        lines.append(f"- {finding['repository']} / {finding['file']}:{finding['line']}: {finding['action']}: {finding['reason']}")
    if not report["unverified"]:
        lines.append("No inspection gaps recorded.")
    lines += ["", "A legacy manifest does not prove that the workflow failed. This is not a full latest-version or runner compatibility audit.", ""]
    return "\n".join(lines)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--owner", required=True)
    parser.add_argument("--policy", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9-]{1,39}", args.owner):
        raise AuditError("Invalid owner")
    policy = json.loads(args.policy.read_text(encoding="utf-8"))
    if policy.get("required_runtime") != "node24" or not isinstance(policy.get("legacy_runtimes"), list):
        raise AuditError("Invalid audit policy")
    report = Scanner(API(os.environ.get("GH_TOKEN", "")), policy).run(args.owner)
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    content = markdown(report)
    (args.output / "report.md").write_text(content, encoding="utf-8")
    if os.getenv("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as stream:
            stream.write(content)
    print(f"Public repositories scanned: {report['repositories_scanned']}; legacy runtimes: {len(report['findings'])}; gaps: {len(report['unverified'])}; private excluded: {report['private_repositories_excluded']}")
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except (AuditError, OSError, ValueError) as error:
        print(f"Audit failed: {error}", file=sys.stderr)
        sys.exit(1)
