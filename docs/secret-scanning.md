# Reusable secret scanning

> 🇧🇷 [Leia em Português](secret-scanning.pt-BR.md)

The [`reusable-secret-scan.yml`](../.github/workflows/reusable-secret-scan.yml) workflow provides a central secret-detection policy for repositories maintained under this account.

It is intentionally language- and framework-agnostic. Scanning operates on Git history and does not require build, restore, dependency installation, or execution of repository code. The same policy can therefore be applied to .NET, Node.js, React, Java, Python, Go, Terraform, and future stacks.

## Security goals

The implementation follows these principles:

- **least privilege** — the `GITHUB_TOKEN` receives only `contents: read`;
- **no repository secret is required** to run the scanner;
- **no `pull_request_target`** — pull requests use the normal unprivileged GitHub Actions context;
- **repository code is not executed** — there is no `dotnet build`, `npm install`, Maven, Gradle, project script, or hook execution;
- **complete Git history is available** — `fetch-depth: 0` allows commit ranges to be scanned correctly;
- **checkout credentials are not persisted** — `persist-credentials: false`;
- **GitHub Actions are pinned to immutable commit SHAs** to reduce tag-mutation risk;
- **the Infisical CLI is pinned to a specific version** and downloaded directly from its official release;
- **the binary SHA-256 is verified before execution**;
- **output is redacted** with `--redact`, avoiding disclosure of detected secret values;
- **fail closed** — findings, scanner/tool failures, and incomplete size coverage invalidate the check;
- **explicit large-blob coverage** — before Infisical runs, every Git blob in the selected revision scope is checked against the same 20 MiB per-target limit used by the scanner; any larger blob produces `coverage-failure` instead of a misleading `clean`;
- **short-lived artifacts** — the redacted SARIF report is retained for only 3 days.

This workflow complements rather than replaces GitHub Secret Scanning and Push Protection. GitHub's native protection can also scan surfaces a CI job cannot cover, including issue, pull-request, Discussion, and wiki content.

## Scan scope

The workflow automatically chooses the smallest safe scope for each event:

| Event | Scope |
| --- | --- |
| `pull_request` | commits introduced by the PR (`base..head`) |
| `push` | commits introduced by the push (`before..after`) |
| `workflow_dispatch`, `schedule`, or a context without a trustworthy range | full history (`--all`) |

This avoids performing a full repository scan for every pull request while preserving the ability to run complete periodic or manual audits.

If the expected range is unavailable locally, the workflow falls back to **full-history**, never to a weaker scan.

## Large tracked files and size coverage

Infisical is intentionally invoked with `--max-target-megabytes 20`. To prevent that limit from creating a blind spot, the workflow first enumerates the Git blob objects reachable in the exact revision scope selected for the scan and checks their object sizes.

The policy is **fail-closed**:

- when every selected Git blob is 20 MiB or smaller, the scanner runs normally;
- when at least one selected Git blob is larger than 20 MiB, Infisical is not allowed to return `clean`; the final result is `coverage-failure` and the check fails;
- the Step Summary reports the configured limit, oversized-blob count, and largest oversized blob size without printing secret contents;
- there is no silent binary or artifact exception.

Large binaries or generated artifacts that are intentionally required should not be handled with a scanner ignore rule. For new assets, prefer Git LFS so Git stores a small pointer instead of the large payload. If an oversized payload is already present in history and a full-history scan selects it, the history must be remediated or rewritten as appropriate before the scan can be considered complete.

The deterministic validation creates a temporary Git repository containing a blob larger than 20 MiB with a PAT-like secret pattern generated at runtime and verifies that the size policy returns `coverage-failure`. A separate small-repository fixture verifies the normal `covered` path.

## Protecting the scanner policy from the pull request itself

Two files can alter local Infisical behavior:

- `.infisical-scan.toml`;
- `.infisicalignore`.

On a pull request these files are treated as **privileged security policy**. If the PR changes either file, the workflow:

1. emits a visible warning;
2. temporarily restores the version from the base branch;
3. runs the scan with that trusted policy.

This prevents a pull request from adding a secret and suppressing the same finding in the same diff.

After a legitimate policy change is reviewed and merged, it becomes effective for subsequent scans.

## Protecting this control plane

This repository consumes the reusable policy through [`control-plane-secret-scan.yml`](../.github/workflows/control-plane-secret-scan.yml).

The caller references the reusable workflow from this repository using a **full immutable commit SHA**, rather than a local mutable path, branch, or tag. A Pull Request therefore cannot weaken `reusable-secret-scan.yml` and have its own required secret-scan check execute that modified policy. Updating the trusted scanner revision requires an explicit reviewed SHA change in the caller.

The caller deliberately has no `pull_request.paths` filter. It therefore publishes its check for every Pull Request, including documentation-only or unrelated automation changes. It also runs on pushes to `main`, every Thursday at 13:17 UTC, and through `workflow_dispatch`.

The caller grants only `contents: read` and does not use `pull_request_target`. It delegates enforcement to the reusable workflow: a clean scan succeeds, while findings or an untrustworthy scanner/tool execution fail closed.

The job publishes the stable **`Protect control plane`** context on every Pull Request and is designed to act as a merge gate. Adding that context as a required status check in the `main-hardened` ruleset will be consolidated in the **final ruleset artifact of roadmap #25**, together with the other required checks. That repository-setting activation is outside the versioned implementation of issue #14; the caller contract is automatically validated by the quality gate to prevent path filters, elevated permissions, mutable references, or loss of fail-closed behavior.

## Using it from another repository

Create a small caller workflow in the consuming repository, for example `.github/workflows/secret-scan.yml`:

```yaml
name: Secret scan

on:
  pull_request:
  push:
    branches:
      - main
  schedule:
    - cron: "17 11 * * 3"
  workflow_dispatch:

permissions:
  contents: read

jobs:
  secrets:
    uses: rodri-oliveira-dev/.github/.github/workflows/reusable-secret-scan.yml@v1
```

**Use this example only after the initial release and `v1` alias have been published.** The `@v1` alias advances through reviewed, backward-compatible releases, while `@v1.0.0` pins one release. For maximum isolation, replace it with a **real full commit SHA** verified against the published release. Do not recommend `@main` for consumers. The control plane's own required caller remains pinned by SHA. See the [versioning, update and rollback policy](reusable-workflow-versioning.md).

## Stack coverage

The scanner does not depend on an extension allowlist. Versioned files are analyzed using Infisical patterns and heuristics, including common cases such as the following.

### .NET

- `appsettings.json` and `appsettings.*.json`;
- `launchSettings.json`;
- `NuGet.Config`;
- connection strings;
- NuGet API keys;
- JWT signing keys;
- Azure, AWS, and GCP credentials;
- certificates and private keys.

### Node.js / React / front-end

- `.env`, `.env.*`, and equivalent environment files;
- `.npmrc`;
- npm tokens;
- API keys used by build scripts;
- third-party service credentials;
- private keys or certificates.

Variables intentionally delivered to the browser bundle — for example framework variables explicitly marked public — **must not be treated as secret storage**. If a value reaches the client, it is public by architecture.

### Java / JVM

- `application.properties`;
- `application.yml` / `application.yaml`;
- `settings.xml`;
- `gradle.properties`;
- registry and artifact-repository credentials;
- keystores, private keys, and cloud-provider tokens.

### Python, Go, and other languages

The same policy covers `.env` files, configuration files, hardcoded tokens, connection strings, cloud credentials, private keys, and other detectable patterns independently of the implementation language.

### Infrastructure and CI/CD

Relevant surfaces also include:

- `*.tfvars` and Terraform configuration;
- Kubernetes manifests and kubeconfig;
- Docker / Compose configuration;
- GitHub Actions workflows;
- deployment configuration;
- service-account keys;
- Shell and PowerShell scripts.

## False positives

A finding should only be ignored after verifying that the value **does not grant real access**.

Prefer specific fingerprints in `.infisicalignore` over broad directory or extension exclusions. Avoid generically ignoring files such as `appsettings*.json`, `.env*`, `application*.yml`, or CI/CD files because these are common exposure surfaces.

Changes to `.infisicalignore` or `.infisical-scan.toml` should receive the same review rigor as any other security configuration change.

Never use an ignore rule to "fix" a real exposed credential.

## Responding to a real secret

When the scanner identifies a real credential:

1. **revoke or rotate the credential immediately**;
2. remove the value from code and move it to the appropriate secret-management mechanism;
3. review service logs and usage for signs of unauthorized use;
4. determine whether Git-history removal is required;
5. only then address preventive rules or documentation.

Rewriting history without revoking the credential does not make an exposed credential safe again.

## Optional repository-local configuration

Repositories may add `.infisical-scan.toml` when they need specific rules or tuning. They may also use `.infisicalignore` for fingerprints of verified false positives.

Local configuration should remain exceptional and restrictive: the central policy is designed to work without language-specific configuration.

References:

- [Infisical CLI secret scanning](https://infisical.com/docs/cli/commands/scan)
- [Infisical secret scanning overview](https://infisical.com/docs/documentation/platform/secret-scanning/overview)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/concepts/secret-security/secret-scanning)
- [GitHub Actions secure use](https://docs.github.com/en/actions/reference/security/secure-use)
