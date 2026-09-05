# Agent governance

The `agent-governance/` directory is the canonical authoring source for reusable AI-agent instructions and skills shared across repositories maintained under `rodri-oliveira-dev`.

## Important: no implicit inheritance

The special GitHub `.github` repository does not make `AGENTS.md` or `.agents/skills` automatically available to Codex in other repositories. A consumer must copy/materialize the selected profile into its own repository.

This is therefore a **control plane for authoring and versioning**, not a hidden runtime inheritance mechanism.

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

## Versioning

The governance contract version lives in `agent-governance/VERSION` and follows semantic versioning.

Governance updates should be treated like dependency updates: review the diff, understand behavior changes, run validation, and merge intentionally.

Do not auto-merge governance changes.

## Consumer update flow

The intended flow is:

```text
.github/agent-governance
        |
        | canonical version
        v
compare selected profile
        |
        v
consumer repository
        |
        v
reviewed Pull Request
        |
        v
AGENTS.md + .agents/skills
```

The first implementation stage is manual. Cross-repository synchronization or drift detection can be added later, once the governance contract has proven stable.

## Local authority

A shared profile is a baseline, not a replacement for repository knowledge. Consumer repositories may extend or override it for architecture, domain behavior, test/build commands, release processes, security boundaries, compatibility rules, or project-specific skills.

The actual repository tree and its local contract remain authoritative.

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

`.github/workflows/agent-governance-validation.yml` validates the canonical version, required profile files, skill frontmatter, duplicate skill names, profile references, and key context/validation rules in the .NET library profile.
