# .NET major-version migration recommendation policy

## Decision

The central automation may identify and report repositories that should be
reviewed for a .NET major-version migration. It must not change SDK channels,
TFMs, packages, workloads, runtime images, or publication settings
automatically.

Patch updates within the current `major.minor` SDK channel remain the sole
mutation performed by `dotnet-sdk-sync.yml`. Major-version migration is a
repository-level engineering decision because build success alone does not
prove runtime, package, deployment, or behavioral compatibility.

## Authoritative inputs

Recommendations should be calculated at run time, not from a hard-coded
support table:

- the official [.NET releases index](https://github.com/dotnet/core/blob/main/release-notes/releases-index.json)
  supplies channel, release type, support phase, EOL date, and latest SDK;
- the official [.NET support policy](https://dotnet.microsoft.com/platform/support/policy/dotnet-core)
  defines LTS/STS lifecycle semantics;
- the credential-free repository inventory supplies configured and resolved
  SDKs, project TFMs, Inspector diagnostics, and publication properties;
- repository CI and test results supply compatibility evidence. They are not
  replaced by inventory metadata.

Only stable channels in `active` or `maintenance` support are recommendation
targets. Preview, release-candidate, and `go-live` channels are excluded unless
a future, separately reviewed policy explicitly opts in.

As a dated example, on 2026-10-28 the releases index reports .NET 10 as active
LTS, .NET 8 and .NET 9 in maintenance with EOL on 2026-11-10, and .NET 11 as a
prerelease `go-live` channel. This snapshot is explanatory only; automation
must always read the current index.

## Candidate detection

A repository is a migration candidate when at least one of these conditions is
observed:

1. Its configured root SDK channel is `eol` or absent from supported release
   metadata.
2. Any evaluated project TFM targets an unsupported .NET implementation.
3. A supported channel is within a configurable warning window of its EOL date
   (proposed default: 90 days).
4. The configured SDK and resolved SDK differ across major/minor channels,
   indicating that the declared toolchain is not the toolchain actually used.
5. Inspection is incomplete, contradictory, or reports compatibility
   diagnostics. This produces a `needs-evidence` recommendation, never an
   automatic migration.

Repositories without a root `global.json` may receive an informational
recommendation, but the absence of a pin is not sufficient evidence to create
one automatically.

## Recommendation target

The default target is the newest stable, supported LTS channel compatible with
the repository's verified constraints. A supported current channel is not
reported as obsolete merely because a newer major exists. STS is a valid
explicit repository choice, but it is not the default migration target.

The recommendation should include separate proposed values for:

- SDK channel and exact current patch;
- project TFMs, preserving multi-targeting where it is intentional;
- runtime/container family when it is observable;
- packages or workloads that require manual compatibility review.

It must never imply that changing `global.json` alone completes a runtime or
TFM migration.

## Eligibility and confidence

| Level | Minimum evidence | Result |
| --- | --- | --- |
| `informational` | EOL/near-EOL SDK or TFM detected, but inventory is incomplete | Report only; collect missing evidence |
| `candidate` | Complete inventory, stable target exists, TFMs and SDK use are known | Create a recommendation for repository-owner triage |
| `ready-for-assisted-pr` | Candidate plus green restore/build/tests on an explicit migration branch, package/workload review, and repository opt-in | A future tool may prepare a PR for human review |

No level authorizes automatic merge. Repositories must remain public and owned
by the configured owner under the current control-plane privacy policy.

## Risk signals

Recommendations must call out, without treating unknown values as safe:

- multi-targeted projects and mixed TFM generations;
- `unknown` or `context-dependent` Inspector states;
- self-contained, Native AOT, trimmed, single-file, or runtime-version-pinned
  publication;
- workload-based projects and platform-specific runtime identifiers;
- Docker base images whose runtime family does not match proposed TFMs;
- package, analyzer, source-generator, or MSBuild target incompatibility;
- breaking changes, serialization differences, globalization behavior,
  hosting changes, and deployment environment constraints;
- missing tests, failed restore/build/test, or incomplete inspection.

DotNetRepoInspector provides evidence, not a vulnerability or compatibility
verdict. MSBuild evaluation can execute repository-defined logic, so it must
remain in the timeout-bounded job with no GitHub App private key, write token,
OIDC token, or artifact runtime token. The privileged SDK sync job must consume
no untrusted MSBuild execution.

## Proposed evolution

1. Extend the inventory artifact with a deterministic, non-mutating
   recommendation section derived from current release metadata.
2. Publish counts by urgency (`eol`, `eol-soon`, `needs-evidence`) in the Actions
   summary without exposing non-public repository metadata.
3. Add fixture-driven policy tests for lifecycle boundaries, date windows,
   preview exclusion, mixed TFMs, and unknown publication states.
4. After operational review, optionally create repository issues or draft PRs
   only for explicit opt-ins. Use a new ownership marker and branch namespace;
   do not reuse `chore/sync-dotnet-sdk`.
5. Keep migration commits, validation, rollout, and rollback owned by each
   repository. Never auto-merge or silently retarget a major version.
