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
grep -Fq 'run_bounded_command "$REPOSITORY_CLONE_TIMEOUT_SECONDS"' "$inventory"
grep -Fq 'run_bounded_command "$REPOSITORY_INSPECTION_TIMEOUT_SECONDS"' "$inventory"
grep -Fq 'timeout --verbose --signal=TERM --kill-after=10s "${seconds}s"' "$inventory"
grep -Fq 'grep -Fq '\''timeout: sending signal TERM to command'\'' "$diagnostics_file"' "$inventory"
[[ "$(grep -Fc 'if [[ "$BOUNDED_COMMAND_TIMED_OUT" == "true" ]]; then' "$inventory")" -eq 2 ]]
if grep -Eq 'clone_exit_code.*(124|137)|inspector_exit_code.*(124|137)' "$inventory"; then
  echo "::error::Exit code alone must not classify command failure as a timeout."
  exit 1
fi
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

# Test the real function extracted from the production inventory run block.
# Shorten only the kill-after grace for this local fixture (10s in production).
awk '
  /^run_bounded_command\(\) \{$/ { selected=1 }
  selected {
    print
    if ($0 == "}") exit
  }
' "$fixture_root/inventory.bash" | sed 's/--kill-after=10s/--kill-after=1s/' > "$fixture_root/timeout-function.sh"
[[ -s "$fixture_root/timeout-function.sh" ]]
bash -n "$fixture_root/timeout-function.sh"
source "$fixture_root/timeout-function.sh"

assert_command_failure_not_timeout() {
  local expected_code="$1"
  shift
  local code
  if run_bounded_command 2 "$fixture_root/command.out" "$fixture_root/command.err" "$fixture_root/timeout.err" "$@"; then
    echo "::error::Command expected to fail with exit $expected_code."
    exit 1
  else
    code=$?
  fi
  [[ "$code" -eq "$expected_code" ]]
  [[ "$BOUNDED_COMMAND_TIMED_OUT" == "false" ]]
}

# 124 is a legitimate command exit status; 137 can be a command receiving
# SIGKILL before its deadline. Neither must increment timeout counters.
assert_command_failure_not_timeout 42 bash -c 'exit 42'
assert_command_failure_not_timeout 124 bash -c 'exit 124'
assert_command_failure_not_timeout 137 bash -c 'kill -KILL "$BASHPID"'

# Repository-controlled stderr must not forge a timeout-owned marker.
assert_command_failure_not_timeout 124 bash -c \
  'printf "%s\\n" "timeout: sending signal TERM to command" >&2; exit 124'

# Force SIGKILL after deadline when a descendant ignores TERM and verify
# the deadline marker is observed, with no descendant left executing.
child_pid_file="$fixture_root/child.pid"
if run_bounded_command 1 "$fixture_root/hung.out" "$fixture_root/hung.err" "$fixture_root/timeout.err" \
  bash -c 'trap "" TERM; sleep 30 & printf "%s\\n" "$!" > "$1"; wait' bash "$child_pid_file"; then
  echo "::error::The intentionally hung process unexpectedly completed."
  exit 1
else
  result=$?
  [[ "$result" -eq 124 || "$result" -eq 137 ]]
  [[ "$BOUNDED_COMMAND_TIMED_OUT" == "true" ]]
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

# The timeout belongs to only one repository; a second repository completes.
results=()
timeouts=0
for repository in hung-repository healthy-repository; do
  if [[ "$repository" == "hung-repository" ]]; then
    results+=("$repository:inspection_timeout")
    timeouts=$((timeouts + 1))
    continue
  fi
  run_bounded_command 2 "$fixture_root/healthy.out" "$fixture_root/healthy.err" "$fixture_root/timeout.err" bash -c 'exit 0'
  [[ "$BOUNDED_COMMAND_TIMED_OUT" == "false" ]]
  results+=("$repository:inspected")
done
[[ "$timeouts" -eq 1 ]]
[[ "${results[*]}" == "hung-repository:inspection_timeout healthy-repository:inspected" ]]

echo "Inventory timeout policy, process-group termination and batch continuation passed."
