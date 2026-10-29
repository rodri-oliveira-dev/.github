# Workflow catalog

> [Português](workflow-catalog.pt-BR.md) · [Architecture](architecture.md) · [Flows](automation-flows.md) · [Operations](operations.md)

This catalog covers all **13 files** under `.github/workflows/` as found on `main` on 2026-10-29. Times are São Paulo (UTC−03); underlying cron is UTC and does not dynamically follow daylight-saving rules. Configuration is not proof that a run succeeded.

## Complete inventory

| Workflow | Responsibility | Schedule and triggers |
| --- | --- | --- |
| [`actions-runtime-audit.yml`](../.github/workflows/actions-runtime-audit.yml) | Audit GitHub Actions runtime declarations across public repositories; optional draft remediation PRs | Daily 07:15; manual |
| [`agent-governance-validation.yml`](../.github/workflows/agent-governance-validation.yml) | Validate skills manifest, semantic/version contracts and synchronization behavior | Every PR; scoped `main` pushes |
| [`control-plane-secret-scan.yml`](../.github/workflows/control-plane-secret-scan.yml) | Apply the reusable Git-history secret scan to this repository | Every PR, `main` push; Thu 10:17; manual |
| [`distribute-agent-skills.yml`](../.github/workflows/distribute-agent-skills.yml) | Review-gated updates to four previously installed managed skills | Selected `main` push; manual |
| [`distribute-coderabbit-config.yml`](../.github/workflows/distribute-coderabbit-config.yml) | Distribute `.coderabbit.yaml` remote pointers by mapped profile | Every 15 days; manual `force`/`dry_run` |
| [`dotnet-repository-inventory.yml`](../.github/workflows/dotnet-repository-inventory.yml) | Read-only .NET project inventory with pinned DotNetRepoInspector | Wed 09:30; manual |
| [`dotnet-sdk-sync-privacy-validation.yml`](../.github/workflows/dotnet-sdk-sync-privacy-validation.yml) | Verify SDK synchronization public-only privacy boundary | Scoped PR / `main` pushes; manual |
| [`dotnet-sdk-sync.yml`](../.github/workflows/dotnet-sdk-sync.yml) | Patch-only updates of root `global.json` SDK within current channel | Mon 09:00; manual |
| [`reusable-secret-scan.yml`](../.github/workflows/reusable-secret-scan.yml) | Reusable language-agnostic secret scan across Git history | `workflow_call`; manual |
| [`reusable-workflow-release.yml`](../.github/workflows/reusable-workflow-release.yml) | Manually publish reviewed SemVer tag, release and major alias | Manual on `main` only |
| [`sonar-project-sync.yml`](../.github/workflows/sonar-project-sync.yml) | Collect open GitHub issues labeled Sonar Quality Issues in Project #1 | Daily 06:00; selected `main` pushes; manual |
| [`sync-agent-skills.yml`](../.github/workflows/sync-agent-skills.yml) | Mirror four allowlisted upstream skills into the central registry | Mon 09:20; manual |
| [`workflow-shell-quality.yml`](../.github/workflows/workflow-shell-quality.yml) | Lint workflow YAML and automation Bash | Every PR, `main` push; manual |

## Credentials, outputs and effects

| Workflow | Permission boundary | Output / effect |
| --- | --- | --- |
| [`actions-runtime-audit.yml`](../.github/workflows/actions-runtime-audit.yml) | Read-only App; write token only with manual `apply_fixes=true` | MD/JSON 7-day artifact; optional draft PR per eligible public repo |
| [`agent-governance-validation.yml`](../.github/workflows/agent-governance-validation.yml) | `contents: read` | `Validate governance source` CI check |
| [`control-plane-secret-scan.yml`](../.github/workflows/control-plane-secret-scan.yml) | `contents: read`; full-SHA-pinned reusable scanner | `Protect control plane` CI; redacted SARIF 3 days |
| [`distribute-agent-skills.yml`](../.github/workflows/distribute-agent-skills.yml) | GitHub App Contents/PRs write | One consumer PR per repository with drift; manual `dry_run=true` default |
| [`distribute-coderabbit-config.yml`](../.github/workflows/distribute-coderabbit-config.yml) | GitHub App Contents/PRs write | PR for changed mapped configuration; profile remains on central `main` |
| [`dotnet-repository-inventory.yml`](../.github/workflows/dotnet-repository-inventory.yml) | Read-only App discovery; separate credential-free inspection | Summary and JSON/CSV, 3-day artifact |
| [`dotnet-sdk-sync-privacy-validation.yml`](../.github/workflows/dotnet-sdk-sync-privacy-validation.yml) | `contents: read` | `Validate SDK sync privacy` CI check |
| [`dotnet-sdk-sync.yml`](../.github/workflows/dotnet-sdk-sync.yml) | GitHub App Contents/PRs write | Per-repository Summary; PRs, no merge; manual `dry_run=false` |
| [`reusable-secret-scan.yml`](../.github/workflows/reusable-secret-scan.yml) | Caller `contents: read`, no repository secret required | Clean/findings/coverage-failure/tool-failure and redacted SARIF |
| [`reusable-workflow-release.yml`](../.github/workflows/reusable-workflow-release.yml) | Job `contents: write` | Immutable version tag and moving backward-compatible major alias |
| [`sonar-project-sync.yml`](../.github/workflows/sonar-project-sync.yml) | Classic PAT `PROJECTS_TOKEN` with `project` scope | Filtered Project view and missing issue additions |
| [`sync-agent-skills.yml`](../.github/workflows/sync-agent-skills.yml) | GitHub App token; central PR | One reviewable PR; `source_ref`/`dry_run` inputs |
| [`workflow-shell-quality.yml`](../.github/workflows/workflow-shell-quality.yml) | `contents: read`, unprivileged tools | `Validate workflows and shell` CI check |

## What the automations do not do

- **.NET SDK sync:** changes only eligible root `global.json` patches within `major.minor`. It does not update TFMs, NuGet, images, major or minor versions. A [major migration recommendation policy](dotnet-major-migration-policy.md) exists, but implementing recommendations remains proposed work.
- **Inventory:** reports MSBuild-evaluated project metadata using SHA-pinned DotNetRepoInspector v1.7.0. It does not run every test suite or certify compatibility.
- **Agent skills:** distributes only four `pull-request-existing` skills from the [manifest](../agent-governance/manifest.json), and only where the consumer already has each target file. Five other skills and the `AGENTS.md` profile remain manual.
- **CodeRabbit:** manages `.coderabbit.yaml` for 20 mapped entries in [five profiles](../coderabbit-templates/repositories.json). `remote_config` targets central `main`; editing the remote template can affect consumers without another PR.
- **Actions audit:** scheduled runs are read-only; only manual `workflow_dispatch` with `apply_fixes=true` enables allowlisted draft remediation PRs. A legacy runtime declaration does not prove runtime failure.
- **Sonar:** syncs existing labeled **GitHub issues**, not raw SonarCloud findings.
- **Secret scan:** consumer adoption requires a local caller workflow; `clean` is not a universal coverage guarantee.
- **Releases:** `.github/reusable-workflows/VERSION` declares `v1.1.0`. Publication is manual, not every merge.
- **Dependabot:** is **not one of the 13 workflows**. Its [configuration](../.github/dependabot.yml) runs Tuesday 10:00, proposes reviewable GitHub Actions updates and never auto-merges.

## Triggers and authority

Mutating workflows use automation branches and reviewable PRs; they must not force-push unproven human work. Collision recovery is implementation-specific: SDK/skills use the shared selector, while CodeRabbit and Actions audit have their own checks. CI checks are not proof of enabled GitHub merge protection. Private repositories are excluded from the main public routines and must not leak metadata into public logs.

See [decision diagrams](automation-flows.md) and [operational guide](operations.md).
