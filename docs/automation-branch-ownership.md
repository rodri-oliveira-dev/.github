# Automation branch ownership

This control plane reserves a small set of branch names for cross-repository maintenance:

| Automation | Reserved branch | Ownership marker |
| --- | --- | --- |
| .NET SDK synchronization | `chore/sync-dotnet-sdk` | `<!-- automation-branch-owner: dotnet-sdk-sync/v1 -->` |
| Upstream agent-skill synchronization | `chore/sync-upstream-agent-skills` | `<!-- automation-branch-owner: sync-upstream-agent-skills/v1 -->` |
| Consumer agent-skill distribution | `chore/sync-agent-governance` | `<!-- automation-branch-owner: distribute-agent-skills/v1 -->` |
| CodeRabbit configuration distribution | `chore/sync-coderabbit-config` | `<!-- automation-branch-owner: coderabbit-config-sync/v1 -->` |

A reserved name alone is never evidence that a branch belongs to automation.

## Provenance contract

Before an existing reserved branch can be mutated by automation, the workflow must prove all of the following:

- the reserved branch is different from the repository default/base branch;
- exactly one open Pull Request exists from that branch in the same repository;
- the Pull Request targets the expected base branch;
- the Pull Request was created by a GitHub automation identity;
- the Pull Request body contains the automation-specific ownership marker;
- fixed-title automation Pull Requests keep the expected title;
- every file in the Pull Request is inside that automation's managed path set;
- the Pull Request head SHA is exactly the SHA currently resolved by the remote branch.

Legacy open Pull Requests created before ownership markers were introduced are
accepted only when all other provenance fields match, the title identifies the
same automation, and every changed file is in that automation's explicit managed
path set. A branch name or commit author alone is never sufficient evidence.

If the branch and matching Pull Request are both absent, the branch may be created. Git pushes use an explicit empty `--force-with-lease` expectation so a branch created by another actor after the check causes the push to fail rather than being reused.

For the Git-based agent-skill workflows, an existing automation-owned branch is refreshed with the captured remote SHA supplied explicitly to `--force-with-lease`. A concurrent push after the provenance check therefore rejects the automation push.

The CodeRabbit configuration distributor follows the same Git-based exact-head contract. It validates the reserved branch and Pull Request provenance, checks out the captured branch head, and pushes with `--force-with-lease`. A new reserved branch is created only with an explicit empty lease, so a concurrently created branch is never silently reused.

The SDK synchronization uses the same exact-head principle through a temporary checkout of the target repository. It fetches the reserved branch, verifies that the fetched head is still the proven SHA, creates the SDK update commit in that target-repository checkout, and pushes it with `--force-with-lease="refs/heads/<branch>:<proven-sha>"`. The push succeeds only while the remote ref is exactly the SHA that passed provenance verification; a concurrent advance, reset to an ancestor, deletion, or replacement is rejected. An already-open automation PR is refreshed to a newer SDK without deleting or recreating its branch, while a branch that already proposes the current latest SDK is left unchanged.

The policy also reads closed and merged Pull Request history. It classifies a
remaining branch as historical-merged, historical-closed, historical-modified after the
recorded PR head, conflicting, or unproven. An open PR whose branch changed
remains `modified` and blocks automated updates. These classifications never grant
permission to rewrite the branch.

## Recovery

The SDK synchronization, upstream skill synchronization, and consumer skill distribution recover a collision by
leaving the reserved branch untouched and selecting the deterministic branch
`<reserved>-<automation-id>-managed`. That recovery branch is subject to the
same provenance and exact-SHA lease checks. A later run reuses its proven open
PR instead of creating another one. Intentionally closed PRs are never reopened,
and no historical branch or commit is deleted automatically.

If both the preferred and recovery branch are unsafe, the repository is recorded
as a security block in the Job Summary and no mutation is attempted. Other
repositories in the batch continue, but the job ultimately fails so the block is
not hidden as success.

When a workflow reports a security block, do not force the automation through the collision.

1. Inspect the reserved branch and any open Pull Request manually.
2. If the branch contains human work, preserve that work on a differently named branch before changing anything.
3. Inspect the deterministic recovery branch and its Pull Request as well as the preferred branch.
4. If a run failed after pushing but before creating its PR, preserve the branch and inspect its diff against the base. Do not create a Pull Request manually as a recovery shortcut: an unverified open PR remains `unproven_open` and blocks automated updates.
5. If the preferred branch is orphaned and the deterministic recovery branch is absent, leave the preferred branch intact: the next run can select the recovery branch. If the recovery branch is orphaned, or both branches are historical, inspect both refs and preserve any human work on a separately named branch. When a branch must be absent for safe selection, a maintainer may close a non-owned PR and delete **only** a verified automation-only branch after inspection. The workflow never deletes branches automatically.
6. If a run failed because a branch changed after the SHA was captured, inspect the new remote commit. Re-run only after confirming the branch is still automation-owned; the fresh run will capture the new SHA.

Never rename, delete, reset, or force-update the repository default branch as part of recovery. Adding the hidden marker manually to an unrelated Pull Request is not a valid substitute for verifying the branch history and ownership.
