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

`base/AGENTS.base.md` contains cross-repository policy that should remain small. A profile contains a ready-to-materialize `AGENTS.md` plus a manifest describing which skills belong to that profile.

The initial profile is `dotnet-library`, derived from the agent baseline proven in `dotnet-library-template`.

The profile is the distributable contract. Repository-local instructions may extend or override it when the project has different architecture, tooling, release, compatibility, or security requirements.

## Versioning

`VERSION` is the governance contract version. Use semantic versioning:

- PATCH: wording/clarity changes that do not materially change expected agent behavior;
- MINOR: additive policy, new skills, or stronger validation that remains compatible with existing consumers;
- MAJOR: changes that materially alter workflow, required gates, file layout, or expected agent behavior.

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

## Distribution

Distribution from this registry to consumer repositories remains deliberately manual in this stage. Upstream ingestion of the four allowlisted skills is automated, but consumer repositories are not updated automatically.

Future automation may read `profile.yml`, compare the selected version with consumer repositories, and open update Pull Requests. It should never treat this repository as an implicit runtime inheritance mechanism.

## Local authority

Shared governance must not erase project knowledge. A repository may keep additional local instructions for:

- architecture and domain constraints;
- build/test commands that differ from the profile;
- public API compatibility rules;
- release and deployment behavior;
- security boundaries;
- repository-specific skills.

When shared and local policy conflict, the consumer repository's explicit local contract and real repository state take precedence.
