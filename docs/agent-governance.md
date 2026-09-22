# Agent governance

The `agent-governance/` directory is the canonical authoring source for reusable AI-agent instructions and skills shared across repositories maintained under `rodri-oliveira-dev`.

## Important: no implicit inheritance

The special GitHub `.github` repository does not make `AGENTS.md` or `.agents/skills` automatically available to Codex in other repositories. A consumer must copy/materialize the selected profile into its own repository.

This is therefore a **control plane for authoring, versioning, validation, and reviewed distribution**, not a hidden runtime inheritance mechanism.

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

`AGENTS.md` is the distributable instruction file. `profile.yml` declares profile identity/version and points to the **canonical** `agent-governance/manifest.json`, which declares the profile instructions and every skill's source, consumer target, ownership and distribution mode.



### Canonical manifest and per-artifact policy

`agent-governance/manifest.json` declares schema version `1`, governance version, the `dotnet-library` profile and all nine skills. The four explicitly upstream-owned skills use `pull-request-existing`: updates arrive in the control plane through a reviewed upstream synchronization PR and are offered to existing consumer files through another reviewed PR. The remaining five skills and profile instructions use `manual`. Each entry explicitly disables auto-merge and preserves consumer-local authority. `profile.yml` no longer repeats skill mappings or a misleading global manual distribution flag.

Both automation workflows source `.github/scripts/agent-governance-manifest.sh`, validate the catalog fail-closed and calculate file mappings with `jq` before changing any branch. The distributor has a broad canonical skills push trigger but only the four `pull-request-existing` entries are eligible for automatic PR distribution. Run `bash .github/scripts/test-agent-governance-manifest.sh` for deterministic positive/negative contract tests. Manifest schema, path, ownership and governance-version inconsistencies stop the merge gate.

### Skills

Skills keep task-specific procedures out of the persistent `AGENTS.md` context.

The initial catalog is split between reusable .NET skills and library-specific skills. Nine skills are included in governance version `1.0.0`.

Four skills are mirrored byte-for-byte from `rodri-oliveira-dev/dotnet-library-template` by `.github/workflows/sync-agent-skills.yml`:

- `dotnet-issue-implementation`;
- `dotnet-bug-investigation`;
- `dotnet-pr-review`;
- `dotnet-security-review`.

## Versioning

The governance contract version lives in `agent-governance/VERSION` and follows semantic versioning.

Governance updates should be treated like dependency updates: review the diff, understand behavior changes, run validation, and merge intentionally.

Do not auto-merge governance changes.


### Automatic contract-version gate

Every Pull Request runs `.github/scripts/check-agent-governance-version.sh` against the PR base SHA as part of the required `Validate governance source` job. Changes to canonical skill files, base policies, profile instructions and semantically changed manifest/profile metadata require a strictly increasing `agent-governance/VERSION` with identical version fields in the manifest and profile. The job does not require a bump for independent READMEs/docs, unrelated workflow changes, or only JSON formatting. See [the governance versioning policy](../agent-governance/README.md#required-version-bump-in-pull-requests) for MAJOR/MINOR/PATCH rules, conservative treatment of distributed instructions and local test commands.

## Consumer update flow

The automated path for the four managed skills is:

```text
dotnet-library-template
        |
        | weekly synchronization PR
        v
.github/agent-governance
        |
        | review + validation + merge
        v
distribute-agent-skills.yml
        |
        +--> consumer repository PR
        +--> consumer repository PR
        +--> already-current repository
```

`.github/workflows/distribute-agent-skills.yml` runs after a managed canonical skill changes on `main` and can also be executed manually in dry-run mode.

The workflow enumerates public repositories visible to the configured GitHub App. A consumer participates only for a managed skill that already exists under its `.agents/skills/<skill>/SKILL.md` path. Missing skills are not installed automatically.

When drift exists, the canonical file replaces the consumer copy byte-for-byte on the automation-owned branch `chore/sync-agent-governance`. One reviewed Pull Request is created or refreshed per repository, regardless of how many managed skills changed. Auto-merge remains disabled.

Both upstream synchronization and consumer distribution prove branch ownership before any force update. The proof correlates the same-repository Pull Request, expected head/base, automation marker, and current remote SHA; the subsequent push is guarded by an explicit SHA-bound `--force-with-lease`. See [automation branch ownership](automation-branch-ownership.md) for collision and recovery handling.

Because the `.github` control repository is public, non-public repositories are skipped so their names and metadata cannot leak through public workflow logs or summaries.

Full profile and `AGENTS.md` synchronization remains manual at this stage.

## Local authority

A shared profile is a baseline, not a replacement for repository knowledge. Consumer repositories may extend or override it for architecture, domain behavior, test/build commands, release processes, security boundaries, compatibility rules, or project-specific skills.

The actual repository tree and its local contract remain authoritative. For automatically managed skills, local divergence is surfaced as a Pull Request rather than overwritten on the default branch.

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

`.github/workflows/agent-governance-validation.yml` validates the canonical version, required profile files, skill frontmatter, duplicate skill names, profile references, key context/validation rules, and the upstream/distribution workflow contracts.

The job name is `Validate governance source`. It runs for every Pull Request. The active `main-hardened` ruleset requires this check from GitHub Actions before merging into `main`; the workflow itself only publishes the check and cannot enforce a merge gate without that ruleset. The workflow deliberately avoids `pull_request.paths` so GitHub always creates the required check; validation runs inside the job rather than being filtered at the event trigger.