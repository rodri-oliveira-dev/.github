# Automation components and local validation

The central workflows are orchestration boundaries: triggers, job permissions, short-lived
credentials, checkout/setup, artifact transfer, and calls to versioned Bash entrypoints in
[`.github/scripts/automation/`](../.github/scripts/automation/). Do not copy business
logic into a workflow `run: |` block. Automation code changes require a reviewed PR and
must pass the required `Validate governance source` check.

| Workflow | Entry point | Invariants |
| --- | --- | --- |
| [Inventory](../.github/workflows/dotnet-repository-inventory.yml) | `dotnet-inventory-discovery.sh`, `dotnet-inventory-trust-boundary.sh`, `dotnet-inventory-checkout-inspector.sh`, `dotnet-inventory-build-inspector.sh`, `dotnet-inventory-inspection.sh` | Discovery owns the read-only App token; inspection is a separate job and receives only a sanitized, short-lived artifact. Inspector is pinned to a full commit SHA. Per-repository clone/inspection timeouts and partial-failure behavior are unchanged. |
| [SDK sync](../.github/workflows/dotnet-sdk-sync.yml) | `dotnet-sdk-sync.sh` | Public repositories only; SDK update policy, source version validation, PR idempotency and branch provenance before mutation. |
| [Managed skill distribution](../.github/workflows/distribute-agent-skills.yml) | `distribute-agent-skills.sh` | Public repositories and existing managed skills only; manifest allowlist, provenance and reviewed PR, never auto-merge. |
| [Upstream skill sync](../.github/workflows/sync-agent-skills.yml) | `sync-agent-skills.sh` | Manifest-derived upstream allowlist, provenance and reviewed PR, never auto-merge. |

The scripts inherit their **job-local environment**, including GitHub's `GITHUB_WORKSPACE`,
`GITHUB_STEP_SUMMARY`, `RUNNER_TEMP`, and each step's explicitly scoped inputs. Do not
persist or pass App credentials to the inventory inspection job; its trust-boundary
check must run before any repository-controlled build. Never run the mutating
entrypoints locally with production credentials just to test a change.

## Deterministic local checks (offline)

Run from the repository root on Linux with Bash, Git, jq, Ruby and GNU coreutils:

```bash
for script in .github/scripts/automation/*.sh; do bash -n "$script"; done
bash .github/scripts/test-automation-extraction.sh
bash .github/scripts/test-inventory-timeout.sh
bash .github/scripts/test-batch-failure-isolation.sh
bash .github/scripts/test-agent-governance-manifest.sh
bash .github/scripts/test-agent-governance-version.sh
ruby .github/scripts/test-agent-governance-semantic.rb
```

The extraction harness invokes the production discovery and inspection trust-boundary
scripts against isolated fixtures: mixed public/private repositories, foreign owners,
a sanitized discovery artifact, injected credential and malformed artifact. The
inventory harness executes the real inspection script with mocked Git and dotnet
commands, including hung inspection, timeout classification, process-group cleanup,
batch continuation and JSON/CSV/Step Summary output. Retry and branch-provenance
regression checks remain in the shared governance workflow. Checks return nonzero
on failure, emit actionable diagnostics, and do not access production repositories.

For manual operational dry-runs, use the existing `workflow_dispatch` inputs for
SDK sync, upstream sync and skill distribution. These execute inside GitHub Actions
with their existing access controls; offline tests must never create consumer PRs.
