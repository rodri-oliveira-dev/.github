# Execution and decision flows

> [Português](automation-flows.pt-BR.md) · [Architecture](architecture.md) · [Catalog](workflow-catalog.md) · [Operations](operations.md)

These Mermaid diagrams describe **implementation contracts and decisions**. They do not represent historical run outcomes or prove a scheduled job ran successfully. Internal labels retain technical workflow terminology to ease troubleshooting.

## 1. SDK patch synchronization

[`dotnet-sdk-sync.yml`](../.github/workflows/dotnet-sdk-sync.yml)

```mermaid
flowchart TD
  A["Discover repositories"] --> B{"Owned, public, non-archived and non-fork?"}
  B -->|No| Skip["Skip; anonymize non-public"]
  B -->|Yes| C{"Root global.json present?"}
  C -->|No| Skip
  C -->|Yes| D["Fetch official stable release metadata"]
  D --> E{"New eligible patch in same major.minor?"}
  E -->|No| Current["Current or ineligible"]
  E -->|Yes| Ownership["Check versions and branch/PR provenance"]
  Ownership --> Safe{"Owned branch or safe recovery available?"}
  Safe -->|No| Block["Security block, preserve existing work"]
  Safe -->|Yes| PR["Create or refresh reviewed PR; no auto-merge"]
  Block --> Summary["Aggregate Summary"]
  PR --> Summary
  Skip --> Summary
  Current --> Summary
```

Only root `global.json` and supported stable updates within the current `major.minor` SDK channel. A collision may select a deterministic recovery branch; otherwise this repository is blocked while the batch continues.

## 2. Read-only .NET inventory

[`dotnet-repository-inventory.yml`](../.github/workflows/dotnet-repository-inventory.yml)

```mermaid
flowchart TD
  A["Read-only App discovery"] --> Filter["Filter public owned active non-fork repos"]
  Filter --> Artifact["Sanitized one-day handoff artifact"]
  Artifact --> Job["Separate inspection without App credentials"]
  Job --> Clone["Clone with timeout"]
  Clone --> Inspect["Pinned DotNetRepoInspector + MSBuild evaluation"]
  Inspect --> Outcome{"Evaluated?"}
  Outcome -->|Yes| Records["Project kind, TFM, SDK, publishing states"]
  Outcome -->|No| Problems["Record warning, error or timeout"]
  Records --> Output["Step Summary + JSON and CSV artifacts, three days"]
  Problems --> Output
```

The only App credential is in discovery. Inspection runs without GitHub App keys, uses SHA-pinned DotNetRepoInspector/MSBuild and bounds clone/evaluation timeouts; errors do not silently count as successful inspection.

## 3. Upstream skills to consumer review

[`sync-agent-skills.yml`](../.github/workflows/sync-agent-skills.yml) · [`distribute-agent-skills.yml`](../.github/workflows/distribute-agent-skills.yml)

```mermaid
flowchart TD
  Up["dotnet-library-template main"] --> Diff["Compare four allowlisted skills byte-for-byte"]
  Diff --> Drift{"Central registry drift?"}
  Drift -->|No| Current["No change"]
  Drift -->|Yes| Central["Create or refresh central PR"]
  Central --> Review["Human review, validation, merge"]
  Review --> Push["Approved main push triggers distribution"]
  Push --> Eligible{"Public consumer with existing managed target?"}
  Eligible -->|No| Skip["Skip missing target or ineligible consumer"]
  Eligible -->|Yes| ConsumerDrift{"File differs from approved central content?"}
  ConsumerDrift -->|No| Current
  ConsumerDrift -->|Yes| ConsumerPR["One PR per repository for changed managed files"]
  ConsumerPR --> Gate["Consumer CI and human review; no auto-merge"]
```

Only four manifest-owned skills are synchronized and distributed; a consumer is eligible for each skill only if the managed target already exists. Five additional skills and profile instructions remain manual.

## 4. CodeRabbit profile distribution

[`distribute-coderabbit-config.yml`](../.github/workflows/distribute-coderabbit-config.yml)

```mermaid
flowchart TD
  Map["Five profiles / mapped repositories.json"] --> Cadence["Fifteen-day cadence or manual dispatch"]
  Cadence --> Repo{"Eligible mapped repo, active and not fork?"}
  Repo -->|No| Skip["Skip"]
  Repo -->|Yes| Pointer["Render remote_config pointer"]
  Pointer --> Compare{"Diff from default branch?"}
  Compare -->|No| Current["Already current"]
  Compare -->|Yes| Proven{"Expected branch and PR ownership proven?"}
  Proven -->|No| Block["Record error; do not overwrite"]
  Proven -->|Yes| PR["Propose config update in PR"]
  PR --> Remote["CodeRabbit reads central template on main"]
```

The workflow uses its own reserved-branch ownership checks, not necessarily the shared SDK/skill recovery policy. The proposed `.coderabbit.yaml` points at a centrally maintained profile on `main`.

## 5. Actions runtime audit and optional remediation

[`actions-runtime-audit.yml`](../.github/workflows/actions-runtime-audit.yml)

```mermaid
flowchart TD
  Run["Daily read-only audit"] --> Scan["Inspect workflow / Action manifests"]
  Scan --> Report["Classify legacy runtimes and unverified dependencies"]
  Report --> Artifact["Seven-day MD and JSON artifact"]
  Artifact --> Opt{"Manual apply_fixes=true?"}
  Opt -->|No| End["End without mutation"]
  Opt -->|Yes| Token["Create repository-scoped write token"]
  Token --> Allow{"Official Action and verified allowlisted fix?"}
  Allow -->|No| Manual["Manual investigation"]
  Allow -->|Yes| Draft["Open draft remediation PR"]
  Draft --> Review["Consumer review and CI"]
```

A scheduled audit is read-only. Only a manually opted-in `apply_fixes=true` run requests scoped write permissions and opens draft PRs for allowlisted, verifiable official Action changes.

## 6. Reusable Git-history secret scanning

[`reusable-secret-scan.yml`](../.github/workflows/reusable-secret-scan.yml)

```mermaid
flowchart TD
  Event["PR, push, schedule or workflow_call"] --> Scope["Select trustworthy commit range; else full history"]
  Scope --> Policy["Use base-branch scanner policy for PR policy edits"]
  Policy --> Size{"Every selected Git blob at most 20 MiB?"}
  Size -->|No| Coverage["coverage-failure"]
  Size -->|Yes| Install["Download and SHA256-verify pinned Infisical CLI"]
  Install --> Scan["Run redacted Git-history scan"]
  Scan --> Status{"Result?"}
  Status -->|No findings| Clean["clean"]
  Status -->|Possible secrets| Findings["findings"]
  Status -->|Tool error| Failure["tool-failure"]
  Clean --> SARIF["Redacted SARIF, 3 days"]
  Findings --> SARIF
  Failure --> SARIF
```

The scanner uses base-branch policy when a PR modifies its own suppression settings; incomplete large-blob coverage and tool errors fail closed. `clean` applies only to the examined scope.

## 7. GitHub issue synchronization to Project #1

[`sonar-project-sync.yml`](../.github/workflows/sonar-project-sync.yml)

```mermaid
flowchart LR
  Issues["Open GitHub issues labeled Sonar Quality Issues"] --> Query["GitHub issue search"]
  Query --> Presence{"Already in Project #1?"}
  Presence -->|No| Add["Add issue to Project"]
  Presence -->|Yes| Existing["Keep existing item"]
  Add --> View["Filtered Sonar Quality Issues view"]
  Existing --> View
```

This workflow searches open labeled **GitHub issues**, not the SonarCloud API. Closed items remain in Project history but disappear from the filtered open-issue view.

## 8. Explicit reusable-workflow publication

[`reusable-workflow-release.yml`](../.github/workflows/reusable-workflow-release.yml)

```mermaid
flowchart TD
  PR["Review version bump in reusable-workflows/VERSION"] --> Main["Merge into main"]
  Main --> Dispatch["Manual workflow_dispatch for declared version"]
  Dispatch --> Validate{"Canonical SemVer, main SHA and ancestry valid?"}
  Validate -->|No| Stop["Fail without retargeting immutable release"]
  Validate -->|Yes| Tag["Create immutable version tag and release"]
  Tag --> Alias["Promote compatible major alias"]
  Alias --> Consumer["Consumers pin major alias, patch tag or full SHA"]
```

The reviewer first merges a version bump. A maintainer explicitly dispatches a matching version from `main`. Existing SemVer tags are immutable; the compatible major alias can advance.

## Further reading

For trust boundaries, see [architecture](architecture.md). For blocked mutations, dry-runs and safe recovery, see [operations](operations.md) and the [branch ownership contract](automation-branch-ownership.md).
