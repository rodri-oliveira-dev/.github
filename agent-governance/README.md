# Agent governance

This directory is the canonical registry and distribution source for reusable agent instructions and skills shared across repositories maintained under `rodri-oliveira-dev`.

It is intentionally separate from repository-local runtime files. Neither GitHub nor Codex automatically inherits `AGENTS.md` or `.agents/skills` from the special `.github` repository. A consumer repository must materialize the selected profile into its own tree.

## Goals

- keep shared agent policy in one reviewed source;
- minimize persistent context by keeping global rules compact and task procedures in skills;
- separate reusable .NET guidance from library-specific guidance;
- preserve repository-local authority for project-specific constraints;
- version governance changes so updates are reviewable and traceable;
- keep deterministic CI/security/quality gates outside the model as enforcement.

## Layout

```text
agent-governance/
├── VERSION
├── manifest.json
├── README.md
├── base/
│   └── AGENTS.base.md
├── profiles/
│   └── dotnet-library/
│       ├── AGENTS.md
│       └── profile.yml
└── skills/
    ├── dotnet/
    │   ├── coverage-analysis/
    │   ├── dotnet-bug-investigation/
    │   ├── dotnet-issue-implementation/
    │   ├── dotnet-pr-review/
    │   ├── dotnet-refactoring-engineer/
    │   ├── dotnet-security-review/
    │   └── test-anti-patterns/
    └── dotnet-library/
        ├── ci-release-governance/
        └── dotnet-library-change/
```

## Composition model

`base/AGENTS.base.md` contains cross-repository policy that should remain small. A profile contains a ready-to-materialize `AGENTS.md` and an identity file, while the **single canonical `manifest.json`** describes which skills belong to the profile and how each artifact is managed.

The initial profile is `dotnet-library`, derived from the agent baseline proven in `dotnet-library-template`.

The profile is the distributable contract. Repository-local instructions may extend or override it when the project has different architecture, tooling, release, compatibility, or security requirements.



## Canonical artifact manifest

[`manifest.json`](manifest.json) is the sole source of truth for schema version, the governance contract version, profile instructions and the nine skills. Every entry declares a canonical `source`, a consumer `target`, upstream ownership (`owner.type: upstream` with repository/path, or `central`), and its own `distribution` policy. `pull-request-existing` is restricted to the four upstream-owned managed skills: central synchronization reviews upstream updates first, then consumer distribution opens a PR **only where the target file already exists**. All other skills and the profile `AGENTS.md` remain `manual`. Every artifact disables auto-merge and preserves `local_authority`. The small `profiles/dotnet-library/profile.yml` retains identity/status/version and points to the canonical manifest rather than duplicating the skill catalog or claiming the entire profile uses one distribution mode.

The upstream and consumer workflows validate the manifest and derive their actual file mappings through `.github/scripts/agent-governance-manifest.sh` using `jq`. An invalid schema, version, source, target or ownership policy blocks mutation. The distributor's broad push path filter wakes it for canonical skill changes, but **only** entries with `distribution.mode: pull-request-existing` are processed; manual artifacts never become automatically managed by triggering the workflow. Run `bash .github/scripts/test-agent-governance-manifest.sh` locally to validate the catalog, mappings and negative fixtures. Future additions/ownership changes require a reviewed update to the manifest and canonical source files. Contract-version enforcement is applied to every Pull Request by `Validate governance source`.

## Versioning

`VERSION` is the governance contract version. Use semantic versioning:

- PATCH: compatible corrections/clarifications to distributed instructions or skill procedures that do not remove existing capabilities;
- MINOR: additive skills, profile fields or policies that remain compatible with existing consumer contracts;
- MAJOR: incompatible changes to required behavior, source/target layout, existing skill semantics or required gates.


### Required version bump in Pull Requests

The required `Validate governance source` check compares the PR's merge result with the exact base commit. Any changed, added, renamed or removed contractual file under `agent-governance/` requires `VERSION` to **increase**: this includes base policies, profile instructions, skills (even wording changes within a `SKILL.md`), and the effective contents of `manifest.json` or `profile.yml`. Update the single canonical `VERSION`, `manifest.json`'s `governance_version`, and the profile's `governance_version` together. A downgrade or mismatch fails the check. The gate enforces a strictly increasing SemVer number, but the author and reviewers choose the correct PATCH/MINOR/MAJOR level using the criteria above; it does not infer compatibility from a text diff.

Changes restricted to independent documentation such as `agent-governance/README.md`, repository READMEs or `docs/`, to workflow/automation implementation, or to JSON formatting of the manifest do **not** require a version bump. Updating only the two derived version fields alongside `VERSION` is also not treated as a separate contract change. Ambiguous edits inside distributed skill/policy resources are **conservatively contractual**; do not disguise such edits as documentation-only. The comparison is against the exact PR base, not a hard-coded previous version. The same validation runs in CI for all PRs without a path-filter deadlock; on `main` pushes, its regression suite runs but PR base comparison is skipped.

Run `bash .github/scripts/test-agent-governance-version.sh` for isolated Git regression fixtures. To check the current branch against a local base, run `bash .github/scripts/check-agent-governance-version.sh "$(git rev-parse main)"` from the repository root, when that commit is an ancestor of HEAD.

A consumer should update governance through a reviewed Pull Request. Do not auto-merge governance changes.

## Upstream-owned skills

Four .NET skills are intentionally owned by `rodri-oliveira-dev/dotnet-library-template` and mirrored into this registry:

- `dotnet-issue-implementation`;
- `dotnet-bug-investigation`;
- `dotnet-pr-review`;
- `dotnet-security-review`.

`.github/workflows/sync-agent-skills.yml` checks the upstream `main` branch every Monday at 09:20 `America/Sao_Paulo` (12:20 UTC). The workflow can also be run manually with an alternate source ref for validation.

Synchronization is allowlist-based and byte-for-byte. The workflow does not discover new skills automatically. When drift exists, it creates or updates the automation-owned branch `chore/sync-upstream-agent-skills` and opens a reviewed Pull Request. Auto-merge is intentionally disabled.

Changes to these four mirrored files should normally be authored in the upstream repository. A direct central edit can be replaced by the next synchronization run if it differs from upstream.

Other canonical skills remain centrally maintained unless their ownership is explicitly changed in a reviewed governance update.

## Consumer distribution

After an upstream synchronization Pull Request is reviewed and merged into `main`, `.github/workflows/distribute-agent-skills.yml` is triggered by changes to `agent-governance/manifest.json` or any file under `agent-governance/skills/`. It can also be invoked manually in dry-run mode. The trigger is broader than the managed set: the validated manifest still limits automatic PR distribution to the four `pull-request-existing` skills.

The distributor enumerates public repositories visible to the configured GitHub App and inspects only these existing consumer paths:

- `.agents/skills/dotnet-issue-implementation/SKILL.md`;
- `.agents/skills/dotnet-bug-investigation/SKILL.md`;
- `.agents/skills/dotnet-pr-review/SKILL.md`;
- `.agents/skills/dotnet-security-review/SKILL.md`.

A skill is considered managed only when that path already exists on the consumer repository's default branch. The workflow never installs a missing skill automatically.

For repositories with drift, the canonical file is copied byte-for-byte and the automation creates or refreshes the branch `chore/sync-agent-governance`. One Pull Request is maintained per repository even when several managed skills changed. Auto-merge is disabled, so repository CI and human review remain the merge authority.

Because this control repository is public, non-public repositories are deliberately skipped to avoid exposing their names or metadata through public workflow logs or summaries. Private-repository distribution should run from a private control plane if it is introduced later.

The resulting chain is intentionally review-gated:

```text
dotnet-library-template
        |
        | weekly upstream sync PR
        v
.github/agent-governance
        |
        | reviewed merge to main
        v
consumer distribution workflow
        |
        +--> consumer A update PR
        +--> consumer B update PR
        +--> consumer C already current
```

Full profile and `AGENTS.md` distribution remains manual for now. Only the four explicitly managed skills participate in automatic consumer distribution.

## Local authority

Shared governance must not erase project knowledge. A repository may keep additional local instructions for:

- architecture and domain constraints;
- build/test commands that differ from the profile;
- public API compatibility rules;
- release and deployment behavior;
- security boundaries;
- repository-specific skills.

When shared and local policy conflict, the consumer repository's explicit local contract and real repository state take precedence.
