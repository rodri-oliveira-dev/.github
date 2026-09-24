"""Offline safety and idempotency tests for opt-in remediation."""
import json
import unittest
from pathlib import Path

import yaml

from remediate import API, AuditError, plan_file, replace_line, references, remediate
from test_scanner import FakeAPI, POLICY, repository, tree

SHA = "b" * 40
TARGETS = {"actions/checkout": {"sha": SHA, "version": "v7.0.1"}}

class RemediationAPI(FakeAPI):
    def __init__(self, docs, trees, repos, existing=None, branch_exists=False):
        super().__init__(docs, trees, repos)
        self.existing = existing or []
        self.branch_exists = branch_exists
        self.base_sha = "c" * 40
    def get(self, path, optional=False):
        if "/pulls?" in path:
            return self.existing
        if "/git/ref/heads/automation/" in path:
            return {"object": {"sha": SHA}} if self.branch_exists else None
        if "/git/ref/heads/" in path:
            return {"object": {"sha": self.base_sha}}
        if "/git/commits/" in path:
            return {"tree": {"sha": "d" * 40}}
        raise AssertionError(path)

class FakeWriter:
    def __init__(self):
        self.calls = []
    def post(self, path, payload):
        self.calls.append((path, payload))
        if path.endswith("/git/trees"):
            return {"sha": "e" * 40}
        if path.endswith("/git/commits"):
            return {"sha": "f" * 40}
        if path.endswith("/pulls"):
            return {"html_url": "https://github.com/owner/demo/pull/1"}
        return {}

def docs_for(name="owner/demo", old="v4"):
    base = "c" * 40
    workflow = ("jobs:\n  build:\n    steps:\n      - uses: actions/checkout@" + old +
                " # v4\n        with:\n          persist-credentials: false\n")
    docs = {
        (name, ".github/workflows/ci.yml", base): workflow,
        ("actions/checkout", "action.yml", old): "runs:\n  using: node20\n",
        ("actions/checkout", "action.yml", SHA): "runs:\n  using: node24\n",
    }
    return docs, workflow

class RemediationTests(unittest.TestCase):
    def test_single_direct_use_preserves_with_and_comment(self):
        docs, workflow = docs_for()
        api = RemediationAPI(docs, {}, [])
        rewritten, updates = plan_file(workflow, ".github/workflows/ci.yml", TARGETS, api)
        self.assertEqual(len(updates), 1)
        self.assertIn("checkout@" + SHA + " # v7.0.1", rewritten)
        self.assertIn("persist-credentials: false", rewritten)
        self.assertNotIn("checkout@v4", rewritten)

    def test_shell_uses_not_rewritten(self):
        src = ('jobs:\n  build:\n    steps:\n      - run: |\n          uses: actions/checkout@v4\n'
               '      - uses: actions/checkout@v4\n')
        docs, _ = docs_for()
        api = RemediationAPI(docs, {}, [])
        new, changes = plan_file(src, ".github/workflows/ci.yml", TARGETS, api)
        self.assertEqual(len(changes), 1)
        self.assertIn("          uses: actions/checkout@v4\n", new)
        self.assertIn("      - uses: actions/checkout@" + SHA, new)

    def test_unverified_or_nonlegacy_not_changed(self):
        docs, workflow = docs_for()
        docs[("actions/checkout", "action.yml", "v4")] = "runs:\n  using: node24\n"
        new, updates = plan_file(workflow, ".github/workflows/ci.yml", TARGETS, RemediationAPI(docs, {}, []))
        self.assertEqual(updates, [])
        self.assertEqual(new, workflow)

    def test_target_must_be_node24(self):
        docs, workflow = docs_for()
        docs[("actions/checkout", "action.yml", SHA)] = "runs:\n  using: node20\n"
        with self.assertRaisesRegex(AuditError, "does not declare node24"):
            plan_file(workflow, ".github/workflows/ci.yml", TARGETS, RemediationAPI(docs, {}, []))

    def test_unlisted_action_skipped(self):
        api = RemediationAPI({}, {}, [])
        src = "jobs:\n  build:\n    steps:\n      - uses: third-party/action@v1\n"
        new, changes = plan_file(src, ".github/workflows/ci.yml", TARGETS, api)
        self.assertEqual(changes, [])
        self.assertEqual(api.requests, [])

    def test_duplicate_references_rewritten_independently(self):
        docs, workflow = docs_for()
        doc = workflow + "      - uses: actions/checkout@v4\n"
        new, changes = plan_file(doc, ".github/workflows/ci.yml", TARGETS, RemediationAPI(docs, {}, []))
        self.assertEqual(len(changes), 2)
        self.assertEqual(new.count("checkout@" + SHA), 2)

    def test_existing_pr_prevents_writes(self):
        name = "owner/demo"
        docs, workflow = docs_for()
        api = RemediationAPI(docs, {(name, "c" * 40): tree(".github/workflows/ci.yml")},
                             [repository(name)], existing=[{"html_url": "https://github.com/owner/demo/pull/1"}])
        writer = FakeWriter()
        result = remediate(api, writer, "owner",
                           {"findings": [{"repository": name}]},
                           {"auto_fixes": TARGETS})
        self.assertEqual(result[0]["status"], "existing_pr")
        self.assertEqual(writer.calls, [])

    def test_private_repository_never_written(self):
        name = "owner/secret-project"
        api = RemediationAPI({}, {}, [repository(name, private=True)])
        writer = FakeWriter()
        result = remediate(api, writer, "owner",
                           {"findings": [{"repository": name}]},
                           {"auto_fixes": TARGETS})
        self.assertEqual(result, [])
        self.assertEqual(writer.calls, [])
        self.assertEqual(api.requests, [])

    def test_creates_one_draft_pr_with_atomic_commit(self):
        name = "owner/demo"
        docs, workflow = docs_for()
        api = RemediationAPI(docs, {(name, "c" * 40): tree(".github/workflows/ci.yml")},
                             [repository(name)])
        writer = FakeWriter()
        result = remediate(api, writer, "owner",
                           {"findings": [{"repository": name}]},
                           {"auto_fixes": TARGETS})
        self.assertEqual(result[0]["status"], "created")
        self.assertEqual(len(writer.calls), 4)
        self.assertEqual(writer.calls[-1][1]["draft"], True)
        self.assertEqual(writer.calls[0][1]["tree"][0]["path"], ".github/workflows/ci.yml")
        self.assertIn("checkout@" + SHA, writer.calls[0][1]["tree"][0]["content"])


    def test_stable_branch_prevents_duplicate_pr_after_base_moves(self):
        name = "owner/demo"
        docs, workflow = docs_for()
        api = RemediationAPI(docs, {(name, "c" * 40): tree(".github/workflows/ci.yml")},
                             [repository(name)])
        first_writer = FakeWriter()
        first = remediate(api, first_writer, "owner",
                          {"findings": [{"repository": name}]},
                          {"auto_fixes": TARGETS})
        self.assertEqual(first[0]["status"], "created")
        self.assertEqual(first_writer.calls[-1][1]["head"], "automation/actions-node24")

        api.base_sha = "1" * 40
        api.existing = [{"html_url": "https://github.com/owner/demo/pull/1"}]
        second_writer = FakeWriter()
        second = remediate(api, second_writer, "owner",
                           {"findings": [{"repository": name}]},
                           {"auto_fixes": TARGETS})
        self.assertEqual(second[0]["status"], "existing_pr")
        self.assertEqual(second_writer.calls, [])

    def test_existing_automation_branch_requires_manual_review(self):
        name = "owner/demo"
        docs, workflow = docs_for()
        api = RemediationAPI(docs, {(name, "c" * 40): tree(".github/workflows/ci.yml")},
                             [repository(name)], branch_exists=True)
        writer = FakeWriter()
        result = remediate(api, writer, "owner",
                           {"findings": [{"repository": name}]},
                           {"auto_fixes": TARGETS})
        self.assertEqual(result[0]["status"], "existing_branch")
        self.assertIn("manual review", result[0]["reason"].lower())
        self.assertEqual(writer.calls, [])

    def test_quoted_uses_preserves_quote(self):
        line = '      - uses: "actions/checkout@v4" # v4\n'
        new = replace_line(line, "actions/checkout@v4", TARGETS["actions/checkout"])
        self.assertEqual(new, '      - uses: "actions/checkout@' + SHA + '" # v7.0.1\n')

if __name__ == "__main__":
    unittest.main()
