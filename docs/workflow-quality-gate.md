# Workflow and shell quality gate

The [Workflow and shell quality](../.github/workflows/workflow-shell-quality.yml)
workflow publishes the **Validate workflows and shell** job check for **every**
`pull_request`, including documentation-only PRs. It also runs on pushes to
`main` and through `workflow_dispatch`. **Do not add `pull_request.paths` or
`paths-ignore` to this workflow**: a required check that never starts will
remain pending and block legitimate Pull Requests.

The gate checks all `.github/workflows/*.{yml,yaml}` files with
[actionlint](https://github.com/rhysd/actionlint) and all `.sh` files under
`.github/scripts/` and `.github/actions/` with
[ShellCheck](https://github.com/koalaman/shellcheck) at **error** severity.
ShellCheck's warning/style findings are non-blocking for the existing codebase;
errors, malformed YAML and invalid GitHub Actions declarations fail the job.
The current implementation deliberately runs on all supported files rather
than relying on PR path filters. The regression fixture checks the stable job
name, the unfiltered event, malformed workflow rejection and invalid Bash
rejection.

## Reproducible tooling

The workflow uses pinned Linux AMD64 distributions and verifies their SHA256
**before extraction or execution**:

| Tool | Version | Archive SHA256 |
| --- | --- | --- |
| actionlint | 1.7.12 | `8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8` |
| ShellCheck | 0.11.0 | `b7af85e41cc99489dcc21d66c6d5f3685138f06d34651e6d34b42ec6d54fe6f6` |

To reproduce locally on Linux, install these versions from the upstream
releases, verify the above hashes and ensure both executables are on `PATH`.
From the repository root, run:

```bash
bash .github/scripts/workflow-quality-gate.sh
bash .github/scripts/test-workflow-quality-gate.sh
```

The scripts run offline once the tools are installed and return nonzero with
actionable file/line diagnostics for invalid inputs. There are no privileged
credentials in this job; checkout does not persist its token.

## Required check activation in the main ruleset

After the workflow has published its first successful check on a PR, open
[main-hardened](https://github.com/rodri-oliveira-dev/.github/rules/23827922)
in repository Settings → Rules → Rulesets and edit the **required status
checks** rule. Keep all existing checks and protections. Add the exact check
name **`Validate workflows and shell`** and, if the UI offers an expected
source, select **GitHub Actions** (app integration ID `15368`). Save the
ruleset. Do not add the workflow display name (`Workflow and shell quality`)
in place of the *job check name*. The gate has no `pull_request.paths`
filter, so a documentation-only PR still publishes this required check.

For acceptance, verify both: (1) an automation-changing PR that fails a
quality check cannot merge; and (2) a documentation-only PR receives the
check and does not remain pending solely because of its changed paths.

**Activation is a repository-setting change, not a file change in this PR.**
The new gate is present in the proposed code; adding it as required depends
on updating the ruleset after its first run. Do not mark the issue fully
completed until that setting and the first run have been verified.
