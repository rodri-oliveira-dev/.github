# Agent governance

The `agent-governance/` directory is the canonical authoring source for reusable AI-agent instructions and skills shared across repositories maintained under `rodri-oliveira-dev`.

## Important: no implicit inheritance

The special GitHub `.github` repository does not make `AGENTS.md` or `.agents/skills` automatically available to Codex in other repositories. A consumer must copy/materialize the selected profile into its own repository.

This is therefore a **control plane for authoring, versioning, validation, and reviewed distribution**, not a hidden runtime inheritance mechanism.

## Layers

### Base policy

`agent-governance/base/AGENTS.base.md` contains compact cross-repository rules for:

- context management;
- delegation/routing;
- minimal diffs;
- deterministic validation;
- safe delivery behavior.

The base stays intentionally small because persistent instructions consume context on every task.

### Profiles

A profile turns the shared principles into a ready-to-consume repository contract.

The first profile is `dotnet-library`:

```text
agent-governance/profiles/dotnet-library/
├── AGENTS.md
└── profile.yml
```

`AGENTS.md` is the distributable instruction file. `profile.yml` declares the canonical governance version and the skills that must be materialized under `.agents/skills/` in a consumer repository.

### Skills

Skills keep task-specific procedures out of the persistent `AGENTS.md` context.

The initial catalog is split between reusable .NET skills and library-specific skills. Nine skills are included in governance version `1.0.0`.

Four skills are mirrored byte-for-byte from `rodri-oliveira-dev/dotnet-library-template` by `.github/workflows/sync-agent-skills.yml`:

- `dotnet-issue-implementation`;
- `dotnet-bug-investigation`;
- `dotnet-pr-review`;
- `dotnet-security-review`.

## Versioning

The governance contract version lives in `agent-governance/VERSION` and follows semantic versioning.

Governance updates should be treated like dependency updates: review the diff, understand behavior changes, run validation, and merge intentionally.

Do not auto-merge governance changes.

## Consumer update flow

The automated path for the four managed skills is:

```text
dotnet-library-template
        |
        | weekly synchronization PR
        v
.github/agent-governance
        |
        | review + validation + merge
        v
distribute-agent-skills.yml
        |
        +--> consumer repository PR
        +--> consumer repository PR
        +--> already-current repository
```

`.github/workflows/distribute-agent-skills.yml` runs after a managed canonical skill changes on `main` and can also be executed manually in dry-run mode.

The workflow enumerates public repositories visible to the configured GitHub App. A consumer participates only for a managed skill that already exists under its `.agents/skills/<skill>/SKILL.md` path. Missing skills are not installed automatically.

When drift exists, the canonical file replaces the consumer copy byte-for-byte on the automation-owned branch `chore/sync-agent-governance`. One reviewed Pull Request is created or refreshed per repository, regardless of how many managed skills changed. Auto-merge remains disabled.

Because the `.github` control repository is public, non-public repositories are skipped so their names and metadata cannot leak through public workflow logs or summaries.

Full profile and `AGENTS.md` synchronization remains manual at this stage.

## Local authority

A shared profile is a baseline, not a replacement for repository knowledge. Consumer repositories may extend or override it for architecture, domain behavior, test/build commands, release processes, security boundaries, compatibility rules, or project-specific skills.

The actual repository tree and its local contract remain authoritative. For automatically managed skills, local divergence is surfaced as a Pull Request rather than overwritten on the default branch.

## Enforcement model

Agent instructions are soft policy. Deterministic automation remains the enforcement layer:

```text
AGENTS.md / skills
      |
      v
guided implementation
      |
      v
build / tests / analyzers / scanners / quality gates
      |
      v
merge decision
```

The centralized governance must never be used as a reason to remove or bypass CI, CodeQL, dependency review, secret scanning, package validation, or other repository-specific controls.

## Validation

`.github/workflows/agent-governance-validation.yml` validates the canonical version, required profile files, skill frontmatter, duplicate skill names, profile references, key context/validation rules, and the upstream/distribution workflow contracts.
