# .github

[![Sync .NET SDK versions](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-sdk-sync.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-sdk-sync.yml)
[![Inventory .NET repositories](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-repository-inventory.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-repository-inventory.yml)

Central repository for shared community standards and maintenance automation across repositories maintained under the `rodri-oliveira-dev` account.

> 🇧🇷 [Leia em Português](README.pt-BR.md)

## Purpose

This repository provides a consistent baseline for contribution, security, funding, and selected repository-maintenance policies without duplicating the same configuration across multiple projects.

Repository-specific files always take precedence when a project needs different rules, workflows, compatibility requirements, or support policies.

## What is centralized here

| File / workflow | Purpose |
| --- | --- |
| [`.gitattributes`](.gitattributes) | Repository-local line-ending and diff normalization for documentation, JSON, and GitHub Actions workflow files. |
| [`.gitignore`](.gitignore) | Repository-local ignore rules for generated artifacts, temporary validation files, local tool checkouts, and editor/OS files. |
| [`.github.code-workspace`](.github.code-workspace) | VS Code workspace settings and extension recommendations for consistent Markdown, YAML, and GitHub Actions editing. |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Default contribution guidelines, development workflow, Pull Request expectations, code-quality principles, and common .NET validation guidance. |
| [`SECURITY.md`](SECURITY.md) | Default security policy, responsible vulnerability reporting, disclosure expectations, and scope. |
| [`.github/FUNDING.yml`](.github/FUNDING.yml) | GitHub Sponsors configuration. |
| [`.github/workflows/dotnet-sdk-sync.yml`](.github/workflows/dotnet-sdk-sync.yml) | Central automation that checks repository-root `global.json` files and opens SDK update Pull Requests when appropriate. |
| [`.github/workflows/dotnet-repository-inventory.yml`](.github/workflows/dotnet-repository-inventory.yml) | Central read-only automation that inventories .NET projects across repositories accessible to the configured GitHub App. |
| [`.github/workflows/reusable-secret-scan.yml`](.github/workflows/reusable-secret-scan.yml) | Reusable, language-agnostic Git-history secret scanning policy for .NET and future stacks such as Node.js, React, Java, Python, Go, Terraform, Kubernetes, and Docker. |
| [`agent-governance/`](agent-governance/) | Versioned source of truth for reusable agent instructions, profiles, and skills. These files are distributed explicitly to consumer repositories; they are not inherited automatically. |

## How GitHub uses this repository

GitHub supports default community health files through a public repository named `.github`.

When one of my public repositories does not define its own supported community health file, GitHub can use the corresponding default file from this repository.

A repository-local file remains authoritative for that project. This allows shared defaults to coexist with project-specific requirements.

Examples of repository-specific overrides include:

- contribution workflows;
- security support policies;
- issue and Pull Request templates;
- support policies;
- codes of conduct;
- build, testing, release, or compatibility requirements.

## Central .NET automations

### .NET SDK synchronization

The [`dotnet-sdk-sync.yml`](.github/workflows/dotnet-sdk-sync.yml) workflow provides centralized SDK maintenance for repositories accessible to the configured GitHub App.

Its current policy is intentionally conservative:

- checks only the repository-root `global.json`;
- ignores archived repositories and forks;
- ignores preview SDKs;
- keeps updates within the existing `major.minor` channel;
- considers only supported .NET channels in active or maintenance phase;
- uses official Microsoft .NET release metadata;
- opens a Pull Request instead of changing the default branch directly;
- does not auto-merge generated Pull Requests;
- supports a manual `dry_run` mode before applying changes.

The scheduled run executes every Monday at 09:00 in `America/Sao_Paulo` (12:00 UTC).

This workflow is maintenance automation, not a default community-health file inherited automatically by other repositories. It actively evaluates repositories through the GitHub App installation and creates repository-level Pull Requests when an eligible SDK update exists.

### .NET repository inventory

The [`dotnet-repository-inventory.yml`](.github/workflows/dotnet-repository-inventory.yml) workflow builds a consolidated, read-only inventory of .NET projects across repositories accessible to the configured GitHub App.

Because this repository is public, the workflow publishes only public repository metadata in its GitHub Actions Summary and downloadable artifacts. Non-public repositories accessible to the GitHub App are skipped before cloning or reporting so private repository names, paths, frameworks, and SDK versions are not exposed through public workflow runs. If the same workflow is moved to a private repository, it can include non-public repositories because the run output and artifacts inherit that repository's restricted visibility.

It uses [`rodri-oliveira-dev/DotNetRepoInspector`](https://github.com/rodri-oliveira-dev/DotNetRepoInspector) as the source of truth for project inspection. Project classification is based on evaluated MSBuild metadata from the Inspector, not Bash heuristics or raw `.csproj` parsing.

The inventory identifies these project types:

- `web`;
- `worker`;
- `console`;
- `library`;
- `test`;
- `unknown`.

The workflow keeps Target Framework and .NET SDK data separate. A Target Framework such as `net10.0` describes what the project targets at compile/runtime level, while a configured or resolved .NET SDK such as `10.0.100` describes the SDK used to evaluate/build tooling for the repository.

The inventory runs manually through `workflow_dispatch` and weekly on Wednesdays at 09:30 in `America/Sao_Paulo` (12:30 UTC), avoiding the Monday schedule used by SDK synchronization. Concurrency prevents overlapping inventory runs.

The workflow log shows the eligible repository count before inspection starts, then prints per-repository progress in `[current/total]` format with a short final status for each repository. Isolated repository-level failures do not interrupt inspection of the remaining repositories.

The GitHub Actions Summary is the primary visible report. It shows one Markdown table row per `.csproj`, including repository, project path, project type, Target Framework, and SDK, followed by counts for planned and processed repositories, repositories with and without .NET projects, total projects, classification totals, and inspection warnings/errors. Repository-level problems are also consolidated in the summary and at the end of the workflow log.

The workflow also exports:

- `artifacts/dotnet-repository-inventory.csv`;
- `artifacts/dotnet-repository-inventory.json`.

Both files are uploaded as the `dotnet-repository-inventory` artifact with `retention-days: 3`, so they remain downloadable from the workflow run for 3 days.

Repositories without `.csproj` files are counted and do not fail the run. Clone or inspection problems in individual reported repositories are recorded as warnings/status entries, and the consolidated report is still produced. The workflow uses the existing GitHub App credentials, requests only read permissions from GitHub Actions, ignores forks and archived repositories, inspects default branches only, removes per-repository temporary directories after inspection, and does not write to analyzed repositories.

## Reusable security automation

### Secret scanning

The [`reusable-secret-scan.yml`](.github/workflows/reusable-secret-scan.yml) workflow provides a reusable secret-scanning baseline that is intentionally independent of application language or build system.

It scans Git history with the Infisical CLI and is suitable for .NET repositories as well as Node.js/React, Java/JVM, Python, Go, Terraform, Kubernetes, Docker, CI/CD configuration, and future technology stacks.

Its security policy is intentionally conservative:

- requests only `contents: read` from GitHub Actions;
- does not require repository secrets and never builds or executes application code;
- avoids `pull_request_target` and disables persisted checkout credentials;
- checks out full Git history so committed credentials can be detected beyond the current working tree;
- pins GitHub Actions dependencies to immutable commit SHAs;
- downloads a fixed Infisical CLI version and verifies its SHA-256 checksum before execution;
- redacts detected values from scanner output;
- scans only the relevant PR or push commit range when trustworthy and falls back to full-history scanning otherwise;
- treats both detected secrets and scanner/tool failures as failing checks;
- stores only a redacted SARIF report and retains it for 3 days;
- prevents a Pull Request from weakening its own `.infisical-scan.toml` or `.infisicalignore` policy by using the base-branch versions during that PR scan.

False positives should be narrowly reviewed before adding fingerprints or exclusions. A real credential must be revoked or rotated first; ignore rules are not an acceptable remediation for an exposed secret.

Repositories can adopt the policy through a small caller workflow that references this reusable workflow with `workflow_call`. See [`docs/secret-scanning.md`](docs/secret-scanning.md) for adoption examples, supported scenarios, false-positive handling, and incident-response guidance.

## Agent governance

The [`agent-governance/`](agent-governance/) directory is the canonical authoring source for reusable agent instructions and Codex skills. The initial `dotnet-library` profile keeps persistent `AGENTS.md` policy compact and moves task-specific procedures into nine versioned skills.

This repository acts as the authoring/versioning control plane only: other repositories do **not** inherit these files automatically. Adoption is explicit and repository-local authority is preserved. Governance version `1.0.0` is currently distributed manually; future synchronization may open reviewed update Pull Requests, but should not auto-merge them.

See [`docs/agent-governance.md`](docs/agent-governance.md) for the composition model, versioning rules, consumer flow, and enforcement boundaries.

## Repository structure

```text
.
├── .gitattributes
├── .github/
│   ├── FUNDING.yml
│   └── workflows/
│       ├── agent-governance-validation.yml
│       ├── dotnet-repository-inventory.yml
│       ├── dotnet-sdk-sync.yml
│       └── reusable-secret-scan.yml
├── .github.code-workspace
├── .gitignore
├── agent-governance/
│   ├── VERSION
│   ├── base/
│   ├── profiles/
│   └── skills/
├── docs/
│   ├── agent-governance.md
│   ├── agent-governance.pt-BR.md
│   ├── secret-scanning.md
│   └── secret-scanning.pt-BR.md
├── CONTRIBUTING.md
├── SECURITY.md
├── README.md
└── README.pt-BR.md
```

## Design principles

This repository follows a few simple governance principles:

- **shared defaults, local authority** — repository-specific configuration wins when present;
- **least privilege** — cross-repository automation uses a GitHub App with scoped permissions;
- **review before change** — maintenance automation opens Pull Requests instead of merging directly;
- **safe defaults** — version-management automation avoids implicit major/minor migrations;
- **defense in depth** — reusable security checks complement repository-specific controls and GitHub-native security features;
- **observable automation** — workflow results are exposed through GitHub Actions logs, summaries, and short-lived artifacts when structured data is useful;
- **agent guidance, deterministic enforcement** — `AGENTS.md` and skills guide agents while CI, analyzers, scanners, and quality gates decide what is acceptable.

## Contributing

Before submitting a change, review [`CONTRIBUTING.md`](CONTRIBUTING.md).

Changes to shared defaults should remain broadly applicable. Repository-specific behavior generally belongs in the target repository instead of here.

## Security

For vulnerability reporting and disclosure expectations, see [`SECURITY.md`](SECURITY.md).

Do not report sensitive security issues through public GitHub issues.

## Scope

These defaults primarily support the open-source repositories and packages I maintain, with particular emphasis on the .NET ecosystem.

Individual repositories may define additional architecture, CI/CD, testing, packaging, compatibility, release, operational, or agent-governance requirements.
