#!/usr/bin/env bash
# Offline quality gate: requires actionlint and ShellCheck to be present in PATH.
set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

for tool in actionlint shellcheck find xargs; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '::error title=Missing quality tool::%s is required. See docs/workflow-quality-gate.md.\n' "$tool" >&2
    exit 1
  fi
done

shopt -s nullglob
workflows=(.github/workflows/*.yml .github/workflows/*.yaml)
if (( ${#workflows[@]} == 0 )); then
  echo '::error title=No workflows::No GitHub Actions workflow files were found.' >&2
  exit 1
fi
printf 'Validating %s GitHub Actions workflows with actionlint...\n' "${#workflows[@]}"
# Embedded bash is linted separately and includes scripts extracted into versioned files.
actionlint -oneline -shellcheck= "${workflows[@]}"

# Analyze every tracked Bash entrypoint/helper in the automation and local
# composite-action directories, not only scripts modified by the Pull Request.
mapfile -d '' scripts < <(find .github/scripts .github/actions -type f -name '*.sh' -print0 | sort -z)
if (( ${#scripts[@]} == 0 )); then
  echo '::error title=No Bash scripts::No automation scripts were found.' >&2
  exit 1
fi
printf 'Analyzing %s Bash scripts with ShellCheck (error severity)...\n' "${#scripts[@]}"
shellcheck --severity=error -- "${scripts[@]}"
echo 'GitHub Actions and Bash quality gate passed.'
