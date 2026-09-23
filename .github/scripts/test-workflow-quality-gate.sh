#!/usr/bin/env bash
# Test that the required gate cannot become path-filtered or silently ignore
# invalid workflow and shell fixtures. Offline except for preinstalled tools.
set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
workflow=".github/workflows/workflow-shell-quality.yml"
[[ -s "$workflow" ]]

# The job name must remain stable because main branch protection requires it.
grep -Fxq '    name: Validate workflows and shell' "$workflow"
# A filtered pull_request event would leave the required check pending on PRs
# touching only documentation or other paths. The event stanza has no filters.
event_block="$(sed -n '/^on:$/,/^permissions:$/p' "$workflow")"
grep -Fxq '  pull_request:' <<< "$event_block"
if grep -Eq '^[[:space:]]+(paths|paths-ignore):' <<< "$event_block"; then
  echo '::error::Required quality workflow must not filter pull_request paths.' >&2
  exit 1
fi

fixture_root="$(mktemp -d)"
trap 'rm -rf -- "$fixture_root"' EXIT

# This fixture deliberately changes no automation paths. The quality job is
# unconditional; actionlint must reject an invalid workflow when invoked.
cat > "$fixture_root/invalid-workflow.yml" <<'YAML'
name: Invalid test fixture
on: push
jobs:
  invalid:
    runs-on: ubuntu-latest
    steps: not-a-list
YAML
if actionlint -oneline -shellcheck= "$fixture_root/invalid-workflow.yml" > "$fixture_root/actionlint.log" 2>&1; then
  echo '::error::actionlint accepted malformed workflow fixture.' >&2
  exit 1
fi
[[ -s "$fixture_root/actionlint.log" ]]

cat > "$fixture_root/invalid-script.sh" <<'BASH'
#!/usr/bin/env bash
if true; then
  echo "missing fi"
BASH
if shellcheck --severity=error "$fixture_root/invalid-script.sh" > "$fixture_root/shellcheck.log" 2>&1; then
  echo '::error::ShellCheck accepted malformed Bash fixture.' >&2
  exit 1
fi
[[ -s "$fixture_root/shellcheck.log" ]]

echo 'Quality gate trigger, stable check name and negative syntax fixtures passed.'
