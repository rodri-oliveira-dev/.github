# Versioned reusable workflows

The `.github` control plane publishes reusable workflows as a single reviewed
contract. The public entrypoint is
[reusable-secret-scan.yml](../.github/workflows/reusable-secret-scan.yml).
The central `agent-governance/VERSION` is a **separate** contract: changing
reusable workflow behavior does not silently advance agent-governance versions.

## Version and compatibility policy

- **`v1.0.0`**, `v1.0.1`, and later `vMAJOR.MINOR.PATCH` release tags are
  immutable. The repository's existing `release-tags-immutable` ruleset
  prevents retargeting/deleting `v*.*.*` tags. Never recreate an existing
  release tag at a different commit.
- **`v1`** is an intentionally **mutable major alias**. It points to the
  newest reviewed, backward-compatible `v1.x.y` release. Consumers using
  `@v1` accept compatible behavior and security fixes without changing
  their caller. Changes that remove or rename inputs/outputs, change
  permissions/secrets expectations, or materially break documented behavior
  require **`v2.0.0` and `v2`**, not a breaking update to `v1`.
- `vMAJOR.MINOR.PATCH` pins a fixed *release version*. For maximum
  reproducibility and supply-chain isolation, use the **full commit SHA**
  to which that tag resolves. Validate the tag-to-commit mapping before
  selecting a SHA; never shorten it.
- Do not recommend `@main`: every ordinary merge to `main` otherwise
  changes consumer behavior without a release, compatibility review or opt-in.

## First release and controlled promotion

The reviewed release version is stored in
[`.github/reusable-workflows/VERSION`](../.github/reusable-workflows/VERSION).
The initial value is **`v1.0.0`**. Consumers must wait until the release and
`v1` alias are visible before adopting the examples below.

A release is **merge-driven and review-gated**: changing `VERSION` requires a
Pull Request. Only after that reviewed change reaches `main` does
[Publish reusable workflow release](../.github/workflows/reusable-workflow-release.yml)
run with `contents: write`. The workflow never runs on `pull_request`.
Its `push` trigger is restricted to `main` and to the `VERSION` path, so
ordinary merges do not publish releases. `workflow_dispatch` remains
available for an idempotent retry/recovery of the version currently declared
on `main`.

The workflow resolves the version from the reviewed file, validates canonical
`vMAJOR.MINOR.PATCH` format, repository, branch and full 40-character commit
SHA, creates the immutable tag and GitHub Release, then advances the matching
major alias. It refuses to retarget an existing version tag, rejects SemVer
regression within a major, and will not move a major alias to a non-descendant
commit. Rerunning the same version at the same commit is idempotent. If the
release is published but alias promotion fails, resolve that failure before
recommending `@v1`; consumers may still use a verified exact tag/SHA.

For a compatible release, bump `VERSION` in a reviewed PR (for example,
`v1.0.1`) and merge it to `main`; never move `v1.0.0`. Breaking changes
require a new major (for example, `v2.0.0`) with documented migration steps,
preserving the preceding major line for consumers that have not migrated.
The major alias changes only through this privileged release workflow, never
by renaming a branch or by automerging dependency PRs.

## Consumer example

The following example is valid **after `v1` has been published**. It
uses only read access; the caller has no privileged `pull_request_target`
trigger.

```yaml
name: Secret scan
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  secrets:
    uses: rodri-oliveira-dev/.github/.github/workflows/reusable-secret-scan.yml@v1
```

For an immutable release version, replace `@v1` with `@v1.0.0` after
the initial release. For strict immutable provenance, replace it with
`@<40-character-commit-SHA>` **using the real SHA resolved from the
approved release**. Do not copy a placeholder SHA into a workflow.

The **control plane's own required secret-scan caller** is intentionally
pinned to a verified full SHA rather than the moving `@v1` alias: an
unreviewed change to the reusable scanner in a PR must not weaken its
own required security check. Updates to that pinned caller require a
separate reviewed PR and the existing governance tests.

## Updating, rollback and operational checks

1. Review the release notes and any input/output, runtime or secret/
   permission changes. Bump `.github/reusable-workflows/VERSION` in a
   reviewed PR, merge it to `main`, then verify the candidate release and
   `v1` point to that approved commit and wait for the release job to succeed.
2. A consumer on `@v1` automatically follows compatible promotions; a
   consumer on `@v1.0.0` or a SHA must explicitly change its caller in a
   reviewed PR and rerun secret scanning and repository-specific CI.
3. To roll back a consumer, change its caller in a reviewed PR to the
   previously validated exact patch tag or commit SHA. Do **not** rewrite
   an immutable release tag to roll back. If an alias must be suspended
   due to an incident, stop promoting it and publish a reviewed compatible
   corrective patch; do not silently introduce breaking changes under
   the same major.
4. Confirm the [release](https://github.com/rodri-oliveira-dev/.github/releases)
   exists, its tag resolves to the reviewed commit and the reusable
   workflow executes successfully from that published ref. Until this
   verification, release publication remains an outstanding operational
   step of issue #24.
