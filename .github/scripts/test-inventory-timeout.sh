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


# Execute the full production inspection block, not a fixture-specific loop.
# Mock only external git/dotnet commands: discovery, clone, timeout handling,
# JSON/CSV emission and Summary remain the exact workflow implementation.
mock_bin="$fixture_root/mock-bin"
mkdir -p "$mock_bin" "$fixture_root/artifacts"
cat > "$mock_bin/git" <<'GIT_FIXTURE'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$1" == "clone" ]] || exit 97
source_url=""
destination=""
for arg in "$@"; do
  if [[ "$arg" == https://github.com/* ]]; then
    source_url="$arg"
  fi
  destination="$arg"
done
[[ -n "$source_url" && -n "$destination" ]] || exit 98
mkdir -p "$destination"
printf '%s\n' '<Project Sdk="Microsoft.NET.Sdk"></Project>' > "$destination/Sample.csproj"
if [[ "$source_url" == */hung-repository.git ]]; then
  : > "$destination/.hang"
fi
GIT_FIXTURE

cat > "$mock_bin/dotnet" <<'DOTNET_FIXTURE'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$1" == "run" ]] || exit 97
repository_path=""
report_path=""
while (($#)); do
  case "$1" in
    --)
      repository_path="$2"
      shift 2
      ;;
    --output)
      report_path="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
[[ -n "$repository_path" && -n "$report_path" ]] || exit 98
if [[ -f "$repository_path/.hang" ]]; then
  exec sleep 30
fi
cat > "$report_path" <<'JSON_FIXTURE'
{
  "dotNetSdk": {"configured": {"version": "10.0.100"}, "resolvedVersion": "10.0.100"},
  "diagnostics": [],
  "projects": [{
    "path": "Sample.csproj",
    "name": "Sample",
    "classification": {"kind": "library"},
    "targetFrameworks": ["net10.0"],
    "sdks": [],
    "diagnostics": [],
    "isTestProject": false,
    "isPackable": true,
    "outputType": "Library"
  }]
}
JSON_FIXTURE
DOTNET_FIXTURE
chmod +x "$mock_bin/git" "$mock_bin/dotnet"

cat > "$fixture_root/repositories.json" <<'JSON_REPOSITORIES'
[
  {"repository": "rodri-oliveira-dev/hung-repository", "default_branch": "main"},
  {"repository": "rodri-oliveira-dev/healthy-repository", "default_branch": "main"}
]
JSON_REPOSITORIES

# Shorten only the timeout duration and kill grace for local testing.
sed -e 's/--kill-after=10s/--kill-after=1s/' "$fixture_root/inventory.bash" > "$fixture_root/production-inventory.bash"
bash -n "$fixture_root/production-inventory.bash"
PATH="$mock_bin:$PATH" \
OWNER="rodri-oliveira-dev" \
INSPECTOR_VERSION="1.5.2" \
INSPECTOR_SHA="6524981f737086c1fdb370697e5d4100330f9bc3" \
REPOSITORY_CLONE_TIMEOUT_SECONDS=2 \
REPOSITORY_INSPECTION_TIMEOUT_SECONDS=1 \
DISCOVERED_REPOSITORIES_FILE="$fixture_root/repositories.json" \
ARTIFACTS_DIR="$fixture_root/artifacts" \
INSPECTOR_PROJECT="$fixture_root/fixture.csproj" \
GITHUB_STEP_SUMMARY="$fixture_root/step-summary.md" \
  bash "$fixture_root/production-inventory.bash" > "$fixture_root/production-output.log"

report="$fixture_root/artifacts/dotnet-repository-inventory.json"
[[ -s "$report" ]]
jq -e '
  . as $inventory
  | ($inventory.summary.repositories_planned == 2)
    and ($inventory.summary.repositories_processed == 2)
    and ($inventory.summary.repository_inspection_timeouts == 1)
    and ($inventory.summary.repository_clone_timeouts == 0)
    and ($inventory.repositories | length == 2)
    and ($inventory.repositories | map(.repository) ==
      ["rodri-oliveira-dev/hung-repository", "rodri-oliveira-dev/healthy-repository"])
    and ($inventory.repositories | map(.status) == ["inspection_timeout", "inspected"])
    and ($inventory.problems | map(.stage) == ["inspection_timeout"])
    and ($inventory.projects | map(.status) == ["inspection_timeout", "ok"])
' "$report" >/dev/null
grep -Fq 'TIMEOUT rodri-oliveira-dev/hung-repository' "$fixture_root/production-output.log"
grep -Fq 'OK' "$fixture_root/production-output.log"
grep -Fq 'rodri-oliveira-dev/healthy-repository' "$fixture_root/production-output.log"
grep -Fq '| Repository inspection timeouts | 1 |' "$fixture_root/step-summary.md"
grep -Fq 'rodri-oliveira-dev/hung-repository' "$fixture_root/step-summary.md"
test -s "$fixture_root/artifacts/dotnet-repository-inventory.csv"

echo "Inventory timeout policy, production batch continuation, and process-group termination passed."
