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
- the Pull Request body contains the automation-specific ownership marker;
- fixed-title automation Pull Requests keep the expected title;
- the Pull Request head SHA is exactly the SHA currently resolved by the remote branch.

If the branch and matching Pull Request are both absent, the branch may be created. Git pushes use an explicit empty `--force-with-lease` expectation so a branch created by another actor after the check causes the push to fail rather than being reused.

For the Git-based agent-skill workflows, an existing automation-owned branch is refreshed with the captured remote SHA supplied explicitly to `--force-with-lease`. A concurrent push after the provenance check therefore rejects the automation push.

The CodeRabbit configuration distributor follows the same Git-based exact-head contract. It validates the reserved branch and Pull Request provenance, checks out the captured branch head, and pushes with `--force-with-lease`. A new reserved branch is created only with an explicit empty lease, so a concurrently created branch is never silently reused.

The SDK synchronization uses the same exact-head principle through a temporary checkout of the target repository. It fetches the reserved branch, verifies that the fetched head is still the proven SHA, creates the SDK update commit in that target-repository checkout, and pushes it with `--force-with-lease="refs/heads/<branch>:<proven-sha>"`. The push succeeds only while the remote ref is exactly the SHA that passed provenance verification; a concurrent advance, reset to an ancestor, deletion, or replacement is rejected. An already-open automation PR is refreshed to a newer SDK without deleting or recreating its branch, while a branch that already proposes the current latest SDK is left unchanged.

The SDK synchronization no longer deletes an existing `chore/sync-dotnet-sdk` merely because its name is reserved. An existing branch without valid provenance is left untouched and reported as an ownership error.

## Recovery

When a workflow reports an orphaned or unproven reserved branch, do not force the automation through the collision.

1. Inspect the reserved branch and any open Pull Request manually.
2. If the branch contains human work, preserve that work on a differently named branch before changing anything.
3. If it is a stale automation branch, verify that no human commits need to be retained, close the stale Pull Request if one exists, and delete the reserved branch manually.
4. Re-run the automation; with both the reserved branch and its automation Pull Request absent, it can recreate provenance from a clean state.
5. If a run failed because the branch changed after the SHA was captured, inspect the new remote commit. Re-run only after confirming the branch is still automation-owned; the fresh run will capture the new SHA.

Never rename, delete, reset, or force-update the repository default branch as part of recovery. Adding the hidden marker manually to an unrelated Pull Request is not a valid substitute for verifying the branch history and ownership.
