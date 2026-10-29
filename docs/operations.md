# Operations, validation and recovery

> [Português](operations.pt-BR.md) · [Catalog](workflow-catalog.md) · [Mermaid flows](automation-flows.md)

## Diagnosing a workflow run

1. Open [Actions](https://github.com/rodri-oliveira-dev/.github/actions) and identify the workflow's **latest relevant run**. A failure predating a merge may be fixed in source without being validated by a fresh run.
2. Record **run ID**, commit SHA, event (`schedule`, `push`, `workflow_dispatch`), branch, inputs, failed job and step.
3. Inspect `::error` annotations, logs, **Step Summary** and artifacts. Do not expose tokens or private repository metadata in public reports.
4. Distinguish configuration failure, security block, aggregated failure after partial progress, timeout and scanner failure.
5. Before rerunning a mutation, inspect any branches or PRs created by the previous run. A failed job does not roll back completed writes.

## Manual dispatches and effects

| Workflow | Safe mode and effects |
| --- | --- |
| [SDK sync](../.github/workflows/dotnet-sdk-sync.yml) | `dry_run=true` is read-only; manual default `false` can create patch PRs |
| [Upstream skills](../.github/workflows/sync-agent-skills.yml) | Optional `source_ref`; `dry_run=true` creates no PR; default `false` may create central PR |
| [Managed skills](../.github/workflows/distribute-agent-skills.yml) | `dry_run=true` **is the manual default**; `false` may create consumer PRs |
| [CodeRabbit](../.github/workflows/distribute-coderabbit-config.yml) | `dry_run=true` only detects drift; `force=true` bypasses the 15-day cadence |
| [Actions runtime audit](../.github/workflows/actions-runtime-audit.yml) | `apply_fixes=false` is read-only; `true` requests write token and creates eligible draft PRs |
| [Inventory](../.github/workflows/dotnet-repository-inventory.yml) | Read-only; summary and CSV/JSON artifacts retained for three days |
| [Sonar Project](../.github/workflows/sonar-project-sync.yml) | Adds issues to Project #1; requires `PROJECTS_TOKEN` secret |
| [Reusable release](../.github/workflows/reusable-workflow-release.yml) | Manual on `main`, matching declared version; creates tags/releases |

CodeRabbit's scheduled distribution uses a daily cron with an internal gate for the exact 15-day cadence. `force` controls that gate; `dry_run` controls mutations.

## Failure modes and recommended responses

| Symptom | Meaning | Safe action |
| --- | --- | --- |
| `ownership is unproven` | Reserved branch lacks a matching open PR or adequate proof | Preserve branch; inspect prior PR and history before retry |
| `modified`, `unproven_open` | Unexpected SHA, author, base or files; possible human work | Do not delete or force-push; verify provenance |
| `coverage-failure` | Selected blob exceeds 20 MiB; incomplete coverage | Remediate file/history, never mask using ignore |
| `tool-failure` | Secret scanner did not complete reliably | Review CLI, hash, download and logs; do not treat as `clean` |
| `clone_timeout`, `inspection_timeout` | Inventory time limit exceeded | Inspect repository, MSBuild and timeouts without removing isolation |
| `Missing PROJECTS_TOKEN` | Classic Project PAT is missing | Configure GitHub secret, never in code/log |
| Aggregated end-of-batch failure | Other repositories may already have PRs | Inspect Summary and PRs before rerunning |

## Branch provenance and recovery

The [shared contract](automation-branch-ownership.md) applies to SDK and skill synchronization. It checks provenance, remote SHA and path allowlists before updating an automation branch. If the reserved branch has unsafe historical work, the selector may use a deterministic recovery branch; if both are unsafe, it must block the mutation without overwriting existing work.

**Implementations differ:** CodeRabbit distribution has its own branch/PR checks and may block rather than recover; Actions runtime remediation uses the `automation/actions-node24` branch and compare-and-swap to ensure the SHA did not change.

Never delete a branch solely because its name matches an automation convention. If a push succeeded but PR creation failed, record the SHA and inspect the remote state before manual recovery. Do not use blind force-push or deletion as the first response.

## Credentials and privacy

- The workflow `GITHUB_TOKEN` generally uses `contents: read`. Short-lived App tokens request needed Contents, Pull Requests or Workflows permissions only in relevant jobs.
- Main public automations skip non-public repositories and must not reveal their names in public logs.
- The MSBuild inspection job must not receive the App private key or write token.
- Runtime remediation receives repository-scoped write access only after manual `apply_fixes=true` opt-in.
- `PROJECTS_TOKEN` is a separate classic PAT with the `project` scope, not a GitHub App credential.

## Post-merge verification criteria

- For documentation PRs: verify PT-BR/EN parity, all 13 catalog entries, relative links, Mermaid rendering and no workflow changes.
- For code changes: use `Validate governance source`, `Validate workflows and shell`, `Protect control plane` and relevant tests; existing checks are not proof of **required** status in active rulesets.
- After production automation changes: run or observe a relevant job on **merged `main` code**. PR checks alone are not an operational test.
- Do not invoke mutating scripts locally with production credentials merely to validate a PR.

References: [local scripts and tests](automation-components.md), [branch ownership](automation-branch-ownership.md), [secret scanning](secret-scanning.md), [quality gate](workflow-quality-gate.md) and [workflow releases](reusable-workflow-versioning.md).
