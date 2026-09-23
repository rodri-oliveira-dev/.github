# .github

[![Sync .NET SDK versions](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-sdk-sync.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-sdk-sync.yml)
[![Inventory .NET repositories](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-repository-inventory.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-repository-inventory.yml)
[![Control plane secret scan](https://github.com/rodri-oliveira-dev/.github/actions/workflows/control-plane-secret-scan.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/control-plane-secret-scan.yml)
[![Agent governance validation](https://github.com/rodri-oliveira-dev/.github/actions/workflows/agent-governance-validation.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/agent-governance-validation.yml)
[![Sync upstream agent skills](https://github.com/rodri-oliveira-dev/.github/actions/workflows/sync-agent-skills.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/sync-agent-skills.yml)
[![Distribute managed agent skills](https://github.com/rodri-oliveira-dev/.github/actions/workflows/distribute-agent-skills.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/distribute-agent-skills.yml)

Central repository for shared community standards and maintenance automation across repositories maintained under the `rodri-oliveira-dev` account.

> 🇧🇷 [Leia em Português](README.pt-BR.md)

## Purpose

This repository provides a consistent baseline for contribution, security, funding, selected repository-maintenance policies, and agent governance without duplicating the same configuration across multiple projects.

Repository-specific files always take precedence when a project needs different rules, workflows, compatibility requirements, support policies, or local agent instructions.

## What is centralized here

| File / workflow | Purpose |
| --- | --- |
| [`.gitattributes`](.gitattributes) | Repository-local line-ending and diff normalization for documentation, JSON, and GitHub Actions workflow files. |
| [`.gitignore`](.gitignore) | Repository-local ignore rules for generated artifacts, temporary validation files, local tool checkouts, and editor/OS files. |
| [`.github.code-workspace`](.github.code-workspace) | VS Code workspace settings and extension recommendations for consistent Markdown, YAML, and GitHub Actions editing. |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Default contribution guidelines, development workflow, Pull Request expectations, code-quality principles, and common .NET validation guidance. |
| [`SECURITY.md`](SECURITY.md) | Default security policy, responsible vulnerability reporting, disclosure expectations, and scope. |
| [`.github/FUNDING.yml`](.github/FUNDING.yml) | GitHub Sponsors configuration. |
| [`.github/dependabot.yml`](.github/dependabot.yml) | Weekly Dependabot updates for SHA-pinned GitHub Actions with review-gated Pull Requests. |
| [`.github/workflows/dotnet-sdk-sync.yml`](.github/workflows/dotnet-sdk-sync.yml) | Central automation that checks repository-root `global.json` files and opens SDK update Pull Requests when appropriate. |
| [`.github/workflows/dotnet-repository-inventory.yml`](.github/workflows/dotnet-repository-inventory.yml) | Central read-only automation that inventories .NET projects across repositories accessible to the configured GitHub App. |
| [`.github/workflows/reusable-secret-scan.yml`](.github/workflows/reusable-secret-scan.yml) | Reusable, language-agnostic Git-history secret scanning policy for .NET and future stacks such as Node.js, React, Java, Python, Go, Terraform, Kubernetes, and Docker. |
| [`.github/workflows/reusable-workflow-release.yml`](.github/workflows/reusable-workflow-release.yml) | Manual release of reviewed reusable-workflow versions from `main`, with immutable SemVer tags and promoted major aliases. |
| [`.github/workflows/control-plane-secret-scan.yml`](.github/workflows/control-plane-secret-scan.yml) | Applies the reusable secret-scanning policy to this control plane on every Pull Request, pushes to `main`, scheduled audits, and manual runs. |
| [`.github/workflows/agent-governance-validation.yml`](.github/workflows/agent-governance-validation.yml) | Deterministic validation for the central agent-governance registry, profile mappings, managed skills, and synchronization/distribution contracts. |
| [`.github/workflows/sync-agent-skills.yml`](.github/workflows/sync-agent-skills.yml) | Weekly upstream synchronization of four allowlisted .NET skills from `dotnet-library-template` into the central registry through a reviewed Pull Request. |
| [`.github/workflows/distribute-agent-skills.yml`](.github/workflows/distribute-agent-skills.yml) | Distributes approved managed skills from `.github/main` to public consumer repositories that already use them, opening one reviewed Pull Request per repository when drift exists. |
| [`agent-governance/`](agent-governance/) | Versioned canonical registry for reusable agent instructions, profiles, and skills. These files are distributed explicitly to consumer repositories; they are not inherited automatically. |

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
- build, testing, release, or compatibility requirements;
- repository-specific agent instructions and skills.

## GitHub API integration

This repository also acts as a control plane for integrations built on a GitHub App and the GitHub REST API. Maintenance workflows authenticate with short-lived installation tokens and use scoped API operations to discover repositories, read repository metadata and contents, create or update branches, and open reviewable Pull Requests.

Current API-backed integrations include:

- `.NET SDK synchronization`, which discovers repositories, reads `global.json`, creates update branches, writes eligible SDK changes, and opens Pull Requests;
- managed agent-skill distribution, which inspects consumer repositories and creates or refreshes Pull Requests when approved central skills drift;
- `.NET repository inventory`, which uses the GitHub App as a read-only discovery boundary before repository inspection.

The integration model follows least privilege: GitHub App permissions are scoped to each workflow's needs, writes are review-gated through Pull Requests, and read-only workflows do not modify inspected repositories.

Reserved automation branches use an explicit provenance contract rather than trusting a branch name. Existing branches can be refreshed only when a matching open Pull Request from the same repository carries the expected ownership marker and its head SHA matches the current remote ref; force updates additionally use an explicit SHA-bound `--force-with-lease`. See [automation branch ownership](docs/automation-branch-ownership.md) for the full contract and orphaned-branch recovery procedure.

## Automation implementation and local tests

The maintenance workflows are thin orchestration layers. Their versioned Bash components, preserved trust boundaries, and offline regression suites are documented in [automation components and local validation](docs/automation-components.md).

## Workflow and shell quality gate

The [Workflow and shell quality](.github/workflows/workflow-shell-quality.yml) workflow checks all Pull Requests with actionlint and ShellCheck, without a pull-request path filter. The job check `Validate workflows and shell` can be added to the `main-hardened` required checks once its first run exists. See [quality gate documentation and local validation](docs/workflow-quality-gate.md) for reproducible tooling and the ruleset activation steps.

## Versioned reusable workflows

Reusable workflows follow a reviewed release contract: immutable `vMAJOR.MINOR.PATCH` tags, a deliberately moving backward-compatible `vMAJOR` alias for consumers, and full commit SHA for strict reproducibility. The initial `v1.0.0` release and `v1` alias **must be published after this change merges to `main`**; they are not yet available for consumer use. [Versioning, release, update and rollback policy](docs/reusable-workflow-versioning.md) describes the manual, permission-scoped [release workflow](.github/workflows/reusable-workflow-release.yml) and consumer examples. The control plane's own required scanner caller remains SHA-pinned.

## GitHub Actions dependency maintenance

[Dependabot](.github/dependabot.yml) checks the GitHub Actions used by this control plane **every Tuesday at 10:00 (America/Sao_Paulo)**. It opens version-update Pull Requests against `main` for review; this is repository-local configuration, **not** an inherited community-health default for other repositories. No GitHub App credentials, new permissions or auto-merge configuration are needed.

Keep all remote `uses:` references pinned to a **full 40-character commit SHA** and retain the corresponding human-readable release tag in the inline comment, where available. The only grouped updates are minor/patch changes to `actions/upload-artifact` and `actions/download-artifact`, which should be tested together. Major upgrades and credential-bearing actions such as `actions/create-github-app-token` remain separate for focused review.

Before merging a Dependabot PR, check the upstream release notes and the actual commit/tag mapping; review permission changes and the code executed with secrets; confirm that all affected `uses:` references still use immutable SHAs and that version comments match; run the existing governance, privacy and secret-scanning checks. For repository-owned reusable workflows or actions whose SHA is explicitly part of a governance contract, coordinate any pin change with its contract validations rather than bypassing those checks. Keep human approval and merge protection in place; do not auto-merge bot PRs.

After this configuration reaches `main`, use **Insights → Dependency graph → Dependabot** to check when GitHub last scanned for updates. The first bot PR and access to its settings cannot be demonstrated solely by opening this configuration PR.

## Central .NET automations

The [canonical agent-governance manifest](agent-governance/manifest.json) defines the nine skills and per-artifact ownership/distribution policy. Four upstream-owned skills are synchronized and offered to existing consumers by reviewed Pull Request; the other five and profile instructions remain manual. [Agent governance documentation](agent-governance/README.md) explains the schema and local validation.


Governance contract changes are version-gated on every Pull Request: changes to canonical skills, agent policies, profile instructions or manifest/profile semantics require an increasing `agent-governance/VERSION` and matching versions in the manifest and profile. Standalone documentation updates do not require a bump. See [versioning policy](agent-governance/README.md#required-version-bump-in-pull-requests).

### .NET SDK synchronization

The [`dotnet-sdk-sync.yml`](.github/workflows/dotnet-sdk-sync.yml) workflow provides centralized SDK maintenance for repositories accessible to the configured GitHub App.

Its current policy is intentionally conservative:

- checks only the repository-root `global.json`;
- processes only public repositories; non-public repositories are reduced to an anonymous aggregate count before any repository-specific processing or reporting;
- ignores archived repositories and forks;
- ignores preview SDKs;
- keeps updates within the existing `major.minor` channel;
- considers only supported .NET channels in active or maintenance phase;
- uses official Microsoft .NET release metadata;
- opens a Pull Request instead of changing the default branch directly;
- does not auto-merge generated Pull Requests;
- supports a manual `dry_run` mode before applying changes.

The scheduled run executes every Monday at 09:00 in `America/Sao_Paulo` (12:00 UTC). The SDK synchronization job has an explicit **90-minute wall-clock limit**. A job-level timeout cancels the run and may prevent processing remaining repositories or writing its final Summary; it does not retry or roll back an in-flight GitHub mutation. Repository-level operational errors still follow the separate batch-isolation policy below.

This workflow is maintenance automation, not a default community-health file inherited automatically by other repositories. It actively evaluates repositories through the GitHub App installation and creates repository-level Pull Requests when an eligible SDK update exists.

Because this control plane is public, the SDK synchronization treats repository visibility as a trust boundary. The installation discovery output serializes full repository metadata only for entries whose visibility is explicitly `public`; private, internal, missing, or otherwise non-public visibility values are converted immediately to an anonymous sentinel. Public logs and the Job Summary expose only the aggregate count of non-public repositories skipped, and no read/write operation is performed against those repositories by the synchronization loop.

The reserved `chore/sync-dotnet-sdk` branch is never deleted merely because its name matches the automation convention. If it already exists, the workflow requires valid Pull Request provenance before treating it as automation-owned; an orphaned or human-created branch is left untouched and reported as an ownership error.

Each run recalculates the latest eligible stable patch. If the automation-owned Pull Request is stale, the same branch and PR are refreshed to that target; a second PR is not created. If the branch already contains the target `sdk.version`, it is left untouched even when JSON formatting differs. Both current and target versions must use stable numeric `major.minor.patch` format and remain in the same `major.minor` channel before any branch mutation; invalid metadata or an incompatible branch state fails safely.

**Batch failure isolation:** A public repository's API, checkout, commit, push, or PR error is recorded as `error` in its Summary row; other repositories continue. The job reports aggregated repository/ownership/SDK policy errors and fails after the batch, rather than stopping at the first consumer. Only read-only HTTP GET calls retry for transient network failures or HTTP 429/500/502/503/504, at most three attempts with 1s/2s backoff. HTTP 4xx other than 429, ownership failures, and Git/PR mutations are not retried. If the branch push succeeds but PR creation fails, the reserved branch is preserved and reported for manual recovery, never deleted or blindly reused.

### .NET repository inventory

The [`dotnet-repository-inventory.yml`](.github/workflows/dotnet-repository-inventory.yml) workflow builds a consolidated, read-only inventory of .NET projects across repositories accessible to the configured GitHub App.

The workflow uses two explicit trust boundaries. The `discovery` job is the only job that receives the GitHub App credentials; it filters the installation down to owned, public, non-archived, non-fork repositories and transfers only `repository` and `default_branch` through a one-day sanitized artifact. The `inspection` job downloads and validates that artifact before cloning anything, receives no GitHub App private key or cross-repository write token, clones only those public repositories, and runs DotNetRepoInspector/MSBuild in that unprivileged boundary. This remains true even when the GitHub App installation itself is configured for `All repositories`, so non-public repository metadata is not transferred to the inspection job or published by this public control plane.

It uses [`rodri-oliveira-dev/DotNetRepoInspector`](https://github.com/rodri-oliveira-dev/DotNetRepoInspector) as the source of truth for project inspection. The executable source is pinned to **v1.5.2** at immutable commit `6524981f737086c1fdb370697e5d4100330f9bc3`; the workflow verifies the detached checkout resolves to that exact SHA before restore/build. Project classification is based on evaluated MSBuild metadata from the Inspector, not Bash heuristics or raw `.csproj` parsing.

The Inspector version and SHA are recorded in the workflow log, GitHub Actions Summary, JSON artifact metadata, and every CSV row. Updating the Inspector is a reviewed control-plane change: verify the desired stable release and its commit in `DotNetRepoInspector`, update `INSPECTOR_VERSION` and `INSPECTOR_SHA` together in `dotnet-repository-inventory.yml`, and merge the change through a Pull Request. `Validate governance source` rejects mutable `main`/`master` checkout patterns and any non-40-character SHA.

The inventory identifies these project types:

- `web`;
- `worker`;
- `console`;
- `library`;
- `test`;
- `unknown`.

The workflow keeps Target Framework and .NET SDK data separate. A Target Framework such as `net10.0` describes what the project targets at compile/runtime level, while a configured or resolved .NET SDK such as `10.0.100` describes the SDK used to evaluate/build tooling for the repository.

The inventory runs manually through `workflow_dispatch` and weekly on Wednesdays at 09:30 in `America/Sao_Paulo` (12:30 UTC), avoiding the Monday schedule used by SDK synchronization. Concurrency prevents overlapping inventory runs.

**Timeouts and cancellation:** The privileged discovery job is capped at **15 minutes** and the credential-free inspection job at **120 minutes**. Inside inspection, each public repository clone has a **120-second** limit and each Inspector/MSBuild invocation has a **300-second** limit. These per-repository defaults are configured via `REPOSITORY_CLONE_TIMEOUT_SECONDS` and `REPOSITORY_INSPECTION_TIMEOUT_SECONDS` in the `inspection` job's `env` block (allowed ranges: 1–600 and 1–3600 seconds); change these values without editing the inspection logic. GNU `timeout` sends SIGTERM to the command's process group and SIGKILL after a **10-second grace period**; it is intentionally used without `--foreground` so descendants such as `dotnet` and MSBuild are terminated together. A local timeout is recorded as `clone_timeout` or `inspection_timeout` in the JSON repository/problem records, increments dedicated counters in the log and Step Summary, generates `inspection_timeout` fallback rows for discovered projects, cleans up, and proceeds to the next repository. A job-level timeout is a hard ceiling: if it fires, GitHub cancels the remaining work and the final inventory/summary/artifact may be incomplete.

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
- treats detected secrets, scanner/tool failures, and incomplete large-file coverage as failing checks;
- checks the selected Git scope for blobs above the scanner's 20 MiB per-target limit and fails closed instead of reporting a partial scan as clean;
- stores only a redacted SARIF report and retains it for 3 days;
- prevents a Pull Request from weakening its own `.infisical-scan.toml` or `.infisicalignore` policy by using the base-branch versions during that PR scan.

False positives should be narrowly reviewed before adding fingerprints or exclusions. A real credential must be revoked or rotated first; ignore rules are not an acceptable remediation for an exposed secret.

This repository applies the same policy to itself through [`control-plane-secret-scan.yml`](.github/workflows/control-plane-secret-scan.yml). The caller pins the reusable scanner to a reviewed immutable commit SHA, runs on every Pull Request without path filters, on pushes to `main`, weekly, and on demand. Its check is intended to be a required status check of the `main-hardened` ruleset so findings or scanner/tool failures block merge while clean Pull Requests receive a deterministic successful conclusion.

Repositories can adopt the policy through a small caller workflow that references this reusable workflow with `workflow_call`. See [`docs/secret-scanning.md`](docs/secret-scanning.md) for adoption examples, supported scenarios, false-positive handling, and incident-response guidance.

## Agent governance

The [`agent-governance/`](agent-governance/) directory is the canonical registry for reusable agent instructions and Codex skills. The initial `dotnet-library` profile keeps persistent `AGENTS.md` policy compact and moves task-specific procedures into nine versioned skills.

Neither GitHub nor Codex implicitly inherits these files from the special `.github` repository. Consumer repositories keep local authority and opt in by storing the relevant files in their own trees.

### Upstream skill synchronization

Four .NET skills are currently upstream-owned by [`rodri-oliveira-dev/dotnet-library-template`](https://github.com/rodri-oliveira-dev/dotnet-library-template):

- `dotnet-issue-implementation`;
- `dotnet-bug-investigation`;
- `dotnet-pr-review`;
- `dotnet-security-review`.

[`sync-agent-skills.yml`](.github/workflows/sync-agent-skills.yml) runs every Monday at 09:20 in `America/Sao_Paulo` (12:20 UTC) and can also be executed manually in `dry_run` mode or against an alternate source ref.

The workflow synchronizes only those four allowlisted files, validates their required metadata, compares them byte-for-byte with the central registry, and creates or refreshes a single `chore/sync-upstream-agent-skills` Pull Request when drift is detected. New upstream skills are never imported implicitly and the Pull Request is never auto-merged.

### Consumer distribution

After a managed skill update is reviewed and merged into `.github/main`, [`distribute-agent-skills.yml`](.github/workflows/distribute-agent-skills.yml) runs automatically because its `push` trigger matches `agent-governance/manifest.json` and `agent-governance/skills/**`. The broader trigger does not expand distribution: only skills marked `pull-request-existing` in the validated manifest are eligible.

The distributor scans public repositories visible to the configured GitHub App and checks whether each repository already contains any managed skill under `.agents/skills/<skill>/SKILL.md`. Existing managed files are compared byte-for-byte with the approved central version.

When drift exists, the workflow creates or refreshes a single `chore/sync-agent-governance` branch and opens one Pull Request per affected repository, even when several skills changed together. It does not install missing skills, does not modify `AGENTS.md`, does not auto-merge, and does not touch repository-specific files outside the four managed skill paths.

Because this control repository is public, non-public repositories are skipped without exposing their names or metadata in public workflow output. Manual execution defaults to `dry_run: true` so distribution can be inspected without writing to consumer repositories.

Consumer distribution also isolates failures per public repository: read, clone, checkout, commit, push, and PR creation/refresh errors are recorded without suppressing subsequent consumers. The Summary includes an explicit `success`/`current`/`skipped`/`error` status for each evaluated public repository and a final aggregate error count. Read-only API GET calls alone use the bounded transient retry policy above; mutations are never blindly retried. Upstream skill synchronization targets only the central registry (one target), so failures there remain job-level failures rather than consumer-batch errors.

The resulting supply chain is deliberately review-gated:

```text
dotnet-library-template
        |
        | weekly upstream sync
        v
.github agent-governance registry
        |
        | validation + reviewed PR + merge
        v
.github/main
        |
        | managed-skill distribution
        v
consumer repositories
        |
        | repository CI + human review
        v
merge decision
```

[`agent-governance-validation.yml`](.github/workflows/agent-governance-validation.yml) validates the registry and the contracts of both synchronization workflows so the allowlist, mappings, review boundaries, and non-auto-merge behavior remain explicit.

The `Validate governance source` job runs on every Pull Request. The active `main-hardened` ruleset for `main` requires this exact check from GitHub Actions; the workflow alone does not enforce merge protection. Pull Request path filters are intentionally not used so the required check is created even when a change does not touch agent-governance files.

See [`docs/agent-governance.md`](docs/agent-governance.md) for the composition model, versioning rules, synchronization/distribution flow, and enforcement boundaries.

## Repository structure

```text
.
├── .gitattributes
├── .github/
│   ├── FUNDING.yml
│   ├── dependabot.yml
│   └── workflows/
│       ├── agent-governance-validation.yml
│       ├── distribute-agent-skills.yml
│       ├── dotnet-repository-inventory.yml
│       ├── dotnet-sdk-sync.yml
│       ├── reusable-secret-scan.yml
│       └── sync-agent-skills.yml
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
- **review before change** — maintenance and agent-governance automation opens Pull Requests instead of merging directly;
- **safe defaults** — version-management automation avoids implicit major/minor migrations and manual agent distribution defaults to dry-run;
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