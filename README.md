# .github

[![Sync .NET SDK versions](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-sdk-sync.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-sdk-sync.yml)

Central repository for shared community standards and maintenance automation across repositories maintained under the `rodri-oliveira-dev` account.

> 🇧🇷 [Leia em Português](README.pt-BR.md)

## Purpose

This repository provides a consistent baseline for contribution, security, funding, and selected repository-maintenance policies without duplicating the same configuration across multiple projects.

Repository-specific files always take precedence when a project needs different rules, workflows, compatibility requirements, or support policies.

## What is centralized here

| File / workflow | Purpose |
| --- | --- |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Default contribution guidelines, development workflow, Pull Request expectations, code-quality principles, and common .NET validation guidance. |
| [`SECURITY.md`](SECURITY.md) | Default security policy, responsible vulnerability reporting, disclosure expectations, and scope. |
| [`.github/FUNDING.yml`](.github/FUNDING.yml) | GitHub Sponsors configuration. |
| [`.github/workflows/dotnet-sdk-sync.yml`](.github/workflows/dotnet-sdk-sync.yml) | Central automation that checks repository-root `global.json` files and opens SDK update Pull Requests when appropriate. |

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

## Central .NET SDK synchronization

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

## Repository structure

```text
.
├── .github/
│   ├── FUNDING.yml
│   └── workflows/
│       └── dotnet-sdk-sync.yml
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
- **observable automation** — workflow results are exposed through GitHub Actions logs and summaries.

## Contributing

Before submitting a change, review [`CONTRIBUTING.md`](CONTRIBUTING.md).

Changes to shared defaults should remain broadly applicable. Repository-specific behavior generally belongs in the target repository instead of here.

## Security

For vulnerability reporting and disclosure expectations, see [`SECURITY.md`](SECURITY.md).

Do not report sensitive security issues through public GitHub issues.

## Scope

These defaults primarily support the open-source repositories and packages I maintain, with particular emphasis on the .NET ecosystem.

Individual repositories may define additional architecture, CI/CD, testing, packaging, compatibility, release, or operational requirements.
