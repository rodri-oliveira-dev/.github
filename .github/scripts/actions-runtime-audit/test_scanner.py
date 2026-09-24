"""Offline regression tests."""
import json
import unittest
from pathlib import Path
import yaml
from scanner import API, AuditError, Scanner, workflow_uses, markdown
from scope import repository_scope

POLICY = json.loads((Path(__file__).parent / "policy.json").read_text())

class FakeAPI:
    def __init__(self, docs, trees, repos):
        self.docs, self.trees, self.repos = docs, trees, repos
        self.requests = []
    def repositories(self, owner):
        return self.repos
    def tree(self, name, ref):
        return self.trees[(name, ref)]
    def manifest(self, name, path, ref, optional=False):
        self.requests.append((name, path, ref))
        source = self.docs.get((name, path, ref))
        if source is None:
            if optional:
                return None
            raise AuditError("Missing YAML")
        return source, yaml.safe_load(source)

def repository(name, private=False, archived=False, fork=False, node_id="R_test"):
    return dict(full_name=name, owner={"login": name.split("/")[0]}, default_branch="main",
                private=private, archived=archived, fork=fork, node_id=node_id,
                visibility="private" if private else "public")

def tree(*paths, truncated=False):
    return {"tree": [{"path": p, "type": "blob"} for p in paths], "truncated": truncated}

class AuditTests(unittest.TestCase):
    def test_structural_uses_ignores_shell(self):
        doc = yaml.safe_load('jobs:\n  x:\n    steps:\n      - run: |\n          echo "uses: bad/action@v1"\n      - uses: actions/checkout@v4\n')
        self.assertEqual(list(workflow_uses(doc)), ["actions/checkout@v4"])

    def test_repeated_identical_action_references_keep_distinct_lines(self):
        name = "rodrigo/demo"
        source = ("jobs:\n  x:\n    steps:\n"
                  "      - uses: actions/upload-artifact@v4\n"
                  "      - uses: actions/upload-artifact@v4\n"
                  "      - uses: actions/upload-artifact@v4\n")
        docs = {
            (name, ".github/workflows/ci.yml", "main"): source,
            ("actions/upload-artifact", "action.yml", "v4"): "runs:\n  using: node20\n",
        }
        result = Scanner(FakeAPI(docs, {(name, "main"): tree(".github/workflows/ci.yml")},
                                 [repository(name)]), POLICY).run("rodrigo")
        findings = [item for item in result["findings"]
                    if item["action"] == "actions/upload-artifact@v4"]
        self.assertEqual([item["line"] for item in findings], [4, 5, 6])

    def test_pinned_sha_uses_manifest_not_version_comment(self):
        sha = "a" * 40
        name = "rodrigo/demo"
        docs = {
            (name, ".github/workflows/ci.yml", "main"):
                f"jobs:\n  x:\n    steps:\n      - uses: actions/checkout@{sha} # v7\n",
            ("actions/checkout", "action.yml", sha): "runs:\n  using: node20\n"}
        result = Scanner(FakeAPI(docs, {(name, "main"): tree(".github/workflows/ci.yml")},
                                 [repository(name)]), POLICY).run("rodrigo")
        self.assertEqual(len(result["findings"]), 1)
        self.assertEqual(result["findings"][0]["line"], 4)

    def test_reusable_workflow_supports_node24(self):
        name = "rodrigo/demo"
        docs = {(name, ".github/workflows/ci.yml", "main"):
                    "jobs:\n  call:\n    uses: shared/workflows/.github/workflows/test.yml@v1\n",
                ("shared/workflows", ".github/workflows/test.yml", "v1"):
                    "jobs:\n  x:\n    steps:\n      - uses: actions/checkout@v7\n",
                ("actions/checkout", "action.yml", "v7"): "runs:\n  using: node24\n"}
        result = Scanner(FakeAPI(docs, {(name, "main"): tree(".github/workflows/ci.yml")},
                                 [repository(name)]), POLICY).run("rodrigo")
        self.assertEqual(result["findings"], [])
        self.assertEqual(result["unverified"], [])

    def test_local_composite_nested_dependency(self):
        name = "rodrigo/demo"
        docs = {(name, ".github/workflows/ci.yml", "main"):
                    "jobs:\n  x:\n    steps:\n      - uses: ./.github/actions/build\n",
                (name, ".github/actions/build/action.yml", "main"):
                    "runs:\n  using: composite\n  steps:\n    - uses: actions/upload-artifact@v4\n",
                ("actions/upload-artifact", "action.yml", "v4"):
                    "runs:\n  using: node20\n"}
        result = Scanner(FakeAPI(docs, {(name, "main"): tree(
            ".github/workflows/ci.yml", ".github/actions/build/action.yml")},
            [repository(name)]), POLICY).run("rodrigo")
        self.assertEqual(len(result["findings"]), 2)

    def test_private_repos_not_fetched_or_disclosed(self):
        name, private = "rodrigo/public", "rodrigo/secret-project"
        api = FakeAPI({(name, ".github/workflows/ci.yml", "main"): "jobs: {}\n"},
                      {(name, "main"): tree(".github/workflows/ci.yml")},
                      [repository(name), repository(private, private=True)])
        result = Scanner(api, POLICY).run("rodrigo")
        self.assertEqual(result["private_repositories_excluded"], 1)
        self.assertEqual(result["repositories_scanned"], 1)
        self.assertNotIn(private, json.dumps(result) + markdown(result))
        self.assertNotIn(private, repr(api.requests))

    def test_public_forks_are_excluded_before_scanning(self):
        name, fork = "rodrigo/public", "rodrigo/public-fork"
        api = FakeAPI({(name, ".github/workflows/ci.yml", "main"): "jobs: {}\n"},
                      {(name, "main"): tree(".github/workflows/ci.yml")},
                      [repository(name), repository(fork, fork=True)])
        result = Scanner(api, POLICY).run("rodrigo")
        self.assertEqual(result["repositories_scanned"], 1)
        self.assertNotIn(fork, json.dumps(result) + markdown(result))
        self.assertNotIn(fork, repr(api.requests))

    def test_incomplete_tree_and_unreadable_manifest(self):
        name = "rodrigo/demo"
        api = FakeAPI({}, {(name, "main"): tree(".github/workflows/missing.yml", truncated=True)},
                      [repository(name)])
        result = Scanner(api, POLICY).run("rodrigo")
        self.assertEqual(len(result["unverified"]), 2)

    def test_unknown_and_dynamic_action_are_not_clean(self):
        name = "rodrigo/demo"
        dynamic = "$" + "{{ matrix.action }}"
        source = "jobs:\n  x:\n    steps:\n      - uses: unknown/action@v1\n      - uses: " + dynamic + "\n"
        api = FakeAPI({(name, ".github/workflows/ci.yml", "main"): source},
                      {(name, "main"): tree(".github/workflows/ci.yml")}, [repository(name)])
        result = Scanner(api, POLICY).run("rodrigo")
        self.assertEqual(len(result["unverified"]), 2)


    def test_local_reusable_workflow_is_scanned_as_workflow(self):
        name = "rodrigo/demo"
        docs = {(name, ".github/workflows/ci.yml", "main"):
                    "jobs:\n  call:\n    uses: ./.github/workflows/reusable.yml\n",
                (name, ".github/workflows/reusable.yml", "main"):
                    "jobs:\n  x:\n    steps:\n      - uses: actions/checkout@v4\n",
                ("actions/checkout", "action.yml", "v4"): "runs:\n  using: node20\n"}
        result = Scanner(FakeAPI(docs, {(name, "main"): tree(
            ".github/workflows/ci.yml", ".github/workflows/reusable.yml")},
            [repository(name)]), POLICY).run("rodrigo")
        nested = [f for f in result["findings"] if f["action"] == "actions/checkout@v4"]
        self.assertTrue(nested)
        self.assertTrue(any(f["file"] == ".github/workflows/reusable.yml" and f["line"] == 4
                            for f in nested))

    def test_self_repository_action_reference_is_resolved(self):
        name = "rodrigo/demo"
        docs = {(name, ".github/workflows/ci.yml", "main"):
                    "jobs:\n  x:\n    steps:\n      - uses: $/.github/actions/build\n",
                (name, ".github/actions/build/action.yml", "main"):
                    "runs:\n  using: node20\n"}
        result = Scanner(FakeAPI(docs, {(name, "main"): tree(".github/workflows/ci.yml")},
            [repository(name)]), POLICY).run("rodrigo")
        self.assertTrue(any(f["action"] == "$/.github/actions/build" and f["line"] == 4
                            for f in result["findings"]))

    def test_empty_self_repository_reference_is_unverified(self):
        name = "rodrigo/demo"
        docs = {(name, ".github/workflows/ci.yml", "main"):
                    "jobs:\n  x:\n    steps:\n      - uses: $/\n"}
        result = Scanner(FakeAPI(docs, {(name, "main"): tree(".github/workflows/ci.yml")},
            [repository(name)]), POLICY).run("rodrigo")
        self.assertTrue(any(f["reason"] == "Self-repository reference without path"
                            for f in result["unverified"]))

    def test_composite_child_line_number_matches_reported_file(self):
        name = "rodrigo/demo"
        docs = {(name, ".github/workflows/ci.yml", "main"):
                    "jobs:\n  x:\n    steps:\n      - uses: ./.github/actions/build\n",
                (name, ".github/actions/build/action.yml", "main"):
                    "runs:\n  using: composite\n  steps:\n    - uses: actions/upload-artifact@v4\n",
                ("actions/upload-artifact", "action.yml", "v4"):
                    "runs:\n  using: node20\n"}
        result = Scanner(FakeAPI(docs, {(name, "main"): tree(
            ".github/workflows/ci.yml", ".github/actions/build/action.yml")},
            [repository(name)]), POLICY).run("rodrigo")
        nested = [f for f in result["findings"] if f["action"] == "actions/upload-artifact@v4"]
        self.assertTrue(any(f["file"] == ".github/actions/build/action.yml" and f["line"] == 4
                            for f in nested))
        self.assertTrue(any(f["file"] == ".github/workflows/ci.yml" and f["line"] is None
                            for f in nested))

    def test_repository_scope_filters_owner_invalid_and_duplicates(self):
        report = {"findings": [
            {"repository": "rodrigo/beta"},
            {"repository": "other/skip"},
            {"repository": "rodrigo/alpha"},
            {"repository": "RODRIGO/alpha"},
            {"repository": "invalid"},
        ]}
        self.assertEqual(repository_scope(report, "rodrigo"), ["alpha", "beta"])

    def test_external_host_rejected(self):
        with self.assertRaises(AuditError):
            API("fake").get("https://evil.example/path")

if __name__ == "__main__":
    unittest.main()
