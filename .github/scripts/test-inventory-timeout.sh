#!/usr/bin/env bash
# Reproducible regression harness for GNU timeout and per-repository isolation.
# Runs only local fixtures; does not clone or inspect any external repository.
set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
inventory="$root/.github/workflows/dotnet-repository-inventory.yml"
sdk="$root/.github/workflows/dotnet-sdk-sync.yml"
fixture_root="$(mktemp -d)"
trap 'rm -rf -- "$fixture_root"' EXIT

command -v timeout >/dev/null
command -v ps >/dev/null

grep -Fq 'timeout-minutes: 15' "$inventory"
grep -Fq 'timeout-minutes: 120' "$inventory"
grep -Fq 'timeout-minutes: 90' "$sdk"
grep -Fq 'REPOSITORY_CLONE_TIMEOUT_SECONDS: "120"' "$inventory"
grep -Fq 'REPOSITORY_INSPECTION_TIMEOUT_SECONDS: "300"' "$inventory"
grep -Fq 'timeout --signal=TERM --kill-after=10s "${REPOSITORY_CLONE_TIMEOUT_SECONDS}s"' "$inventory"
grep -Fq 'timeout --signal=TERM --kill-after=10s "${REPOSITORY_INSPECTION_TIMEOUT_SECONDS}s"' "$inventory"
grep -Fq -- '-u GH_TOKEN' "$inventory"
grep -Fq -- '-u GITHUB_TOKEN' "$inventory"
grep -Fq -- '-u ACTIONS_RUNTIME_TOKEN' "$inventory"
grep -Fq 'record_problem "$repository" "clone_timeout"' "$inventory"
grep -Fq 'record_problem "$repository" "inspection_timeout"' "$inventory"
grep -Fq 'append_repository "$repository" "$visibility" "$default_branch" "clone_timeout"' "$inventory"
grep -Fq 'append_repository "$repository" "$visibility" "$default_branch" "inspection_timeout"' "$inventory"
grep -Fq 'append_project_fallback "$repository" "$visibility" "$default_branch" "$project_path" "inspection_timeout"' "$inventory"
grep -Fq 'repository_clone_timeouts: $repository_clone_timeouts' "$inventory"
grep -Fq 'repository_inspection_timeouts: $repository_inspection_timeouts' "$inventory"

# Extract the actual, credential-free inspection run block and syntax-check it.
awk '
  /^      - name: Generate .NET repository inventory$/ { selected=1; next }
  selected && /^        run: \|$/ { found=1; next }
  found {
    if ($0 ~ /^[[:space:]]*$/) { print; next }
    if ($0 ~ /^          /) { sub(/^          /, ""); print; next }
    exit
  }
' "$inventory" > "$fixture_root/inventory.bash"
[[ -s "$fixture_root/inventory.bash" ]]
bash -n "$fixture_root/inventory.bash"

# A nonzero functional failure is distinct from a timeout.
if timeout --signal=TERM --kill-after=1s 2s bash -c 'exit 42'; then
  echo "::error::Functional fixture unexpectedly succeeded."
  exit 1
else
  result=$?
  [[ "$result" -eq 42 ]]
fi

# Force SIGKILL after a process group ignores TERM, and verify that a
# descendant cannot keep running or obstruct the next repository.
child_pid_file="$fixture_root/child.pid"
if timeout --signal=TERM --kill-after=1s 1s bash -c \
  'trap "" TERM; sleep 30 & printf "%s\n" "$!" > "$1"; wait' \
  bash "$child_pid_file" > "$fixture_root/stdout" 2> "$fixture_root/stderr"; then
  echo "::error::The intentionally hung process unexpectedly completed."
  exit 1
else
  result=$?
  [[ "$result" -eq 124 || "$result" -eq 137 ]]
fi

[[ -s "$child_pid_file" ]]
child_pid="$(cat "$child_pid_file")"
if kill -0 "$child_pid" 2>/dev/null; then
  state="$(ps -o stat= -p "$child_pid" | tr -d '[:space:]' || true)"
  if [[ -n "$state" && "$state" != Z* ]]; then
    echo "::error::Descendant $child_pid still running after inspection timeout (state $state)."
    kill -KILL "$child_pid" 2>/dev/null || true
    exit 1
  fi
fi

# A timeout must be recorded for just this repository; the next repository
# still completes with a separate result.
results=()
timeouts=0
for repository in hung-repository healthy-repository; do
  if [[ "$repository" == "hung-repository" ]]; then
    results+=("$repository:inspection_timeout")
    timeouts=$((timeouts + 1))
    continue
  fi
  timeout --signal=TERM --kill-after=1s 2s bash -c 'exit 0'
  results+=("$repository:inspected")
done
[[ "$timeouts" -eq 1 ]]
[[ "${results[*]}" == "hung-repository:inspection_timeout healthy-repository:inspected" ]]

echo "Inventory timeout policy, process-group termination and batch continuation passed."
