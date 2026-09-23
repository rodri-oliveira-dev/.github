#!/usr/bin/env bash
# Local, offline regression tests for the extracted automation entrypoints.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT

assert_wrapper() {
  local workflow="$1" script="$2"
  [[ -s "$workflow" && -s "$script" ]]
  bash -n "$script"
  grep -Fq "run: bash \"\$GITHUB_WORKSPACE/$script\"" "$workflow" || {
    echo "::error::Missing automation entrypoint: $workflow -> $script" >&2
    return 1
  }
  if grep -Eq '^[[:space:]]*run: \|[[:space:]]*$' "$workflow"; then
    echo "::error::Long inline Bash block reintroduced: $workflow" >&2
    return 1
  fi
  if grep -Fq '${{' "$script"; then
    echo "::error::GitHub expression leaked into standalone script: $script" >&2
    return 1
  fi
}

inventory=".github/workflows/dotnet-repository-inventory.yml"
sdk=".github/workflows/dotnet-sdk-sync.yml"
distribution=".github/workflows/distribute-agent-skills.yml"
upstream=".github/workflows/sync-agent-skills.yml"

for name in dotnet-inventory-discovery dotnet-inventory-trust-boundary \
  dotnet-inventory-checkout-inspector dotnet-inventory-build-inspector \
  dotnet-inventory-inspection; do
  assert_wrapper "$inventory" ".github/scripts/automation/$name.sh"
done
assert_wrapper "$sdk" ".github/scripts/automation/dotnet-sdk-sync.sh"
assert_wrapper "$distribution" ".github/scripts/automation/distribute-agent-skills.sh"
assert_wrapper "$upstream" ".github/scripts/automation/sync-agent-skills.sh"

# The discovery runner gets a read-only installation token. Inspection is a
# separate job that checks the artifact and never gets an App token or key.
grep -Fq 'permission-contents: read' "$inventory"
grep -Fq 'permission-metadata: read' "$inventory"
grep -Fq 'persist-credentials: false' "$inventory"
grep -Fq 'needs: discovery' "$inventory"
grep -Fq 'retention-days: 1' "$inventory"
awk '/^  inspection:/{inspection=1} inspection{print}' "$inventory" > "$scratch/inspection-job.yml"
if grep -Eq '^[[:space:]]*(GH_TOKEN|GITHUB_TOKEN|DOTNET_SDK_SYNC_APP_PRIVATE_KEY):' "$scratch/inspection-job.yml"; then
  echo "::error::Privileged token or private key present in inspection job." >&2
  exit 1
fi

# Exercise the real discovery entrypoint with mixed visibility and owners.
# The mock supplies API data only; filtering and summary are production code.
mkdir -p "$scratch/bin" "$scratch/runner"
cat > "$scratch/bin/gh" <<'GH_MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$*" == 'api --paginate /installation/repositories?per_page=100 --jq .repositories[]' ]]
cat <<'JSON'
{"full_name":"rodri-oliveira-dev/b-public","owner":{"login":"rodri-oliveira-dev"},"visibility":"public","private":false,"archived":false,"fork":false,"default_branch":"main"}
{"full_name":"rodri-oliveira-dev/internal-sensitive","owner":{"login":"rodri-oliveira-dev"},"visibility":"private","private":true,"archived":false,"fork":false,"default_branch":"secret-main"}
{"full_name":"other-owner/c-public","owner":{"login":"other-owner"},"visibility":"public","private":false,"archived":false,"fork":false,"default_branch":"main"}
{"full_name":"rodri-oliveira-dev/a-public","owner":{"login":"rodri-oliveira-dev"},"visibility":"public","private":false,"archived":false,"fork":false,"default_branch":"stable"}
{"full_name":"rodri-oliveira-dev/archived","owner":{"login":"rodri-oliveira-dev"},"visibility":"public","private":false,"archived":true,"fork":false,"default_branch":"main"}
JSON
GH_MOCK
chmod +x "$scratch/bin/gh"
PATH="$scratch/bin:$PATH" RUNNER_TEMP="$scratch/runner" \
  OWNER="rodri-oliveira-dev" GH_TOKEN="fixture-only" \
  GITHUB_STEP_SUMMARY="$scratch/summary.md" \
  bash .github/scripts/automation/dotnet-inventory-discovery.sh

artifact="$scratch/runner/dotnet-repository-discovery/repositories.json"
jq -e '
  . == [
    {"repository":"rodri-oliveira-dev/a-public","default_branch":"stable"},
    {"repository":"rodri-oliveira-dev/b-public","default_branch":"main"}
  ]
' "$artifact" >/dev/null
grep -Fq 'Eligible public repositories: 2' "$scratch/summary.md"
if grep -Eq 'internal-sensitive|secret-main|other-owner' "$artifact" "$scratch/summary.md"; then
  echo "::error::Non-public or foreign repository metadata appeared in public outputs." >&2
  exit 1
fi

# Privileged credentials and malformed artifacts must fail the inspection gate.
env -u GH_TOKEN -u GITHUB_TOKEN -u DOTNET_SDK_SYNC_APP_CLIENT_ID \
  -u DOTNET_SDK_SYNC_APP_PRIVATE_KEY DISCOVERED_REPOSITORIES_FILE="$artifact" \
  bash .github/scripts/automation/dotnet-inventory-trust-boundary.sh
if GH_TOKEN="fixture-only" DISCOVERED_REPOSITORIES_FILE="$artifact" \
  bash .github/scripts/automation/dotnet-inventory-trust-boundary.sh > "$scratch/error.log" 2>&1; then
  echo "::error::Inspection accepted a privileged token." >&2
  exit 1
fi
grep -Fq 'Privileged credential leaked into inspection job: GH_TOKEN' "$scratch/error.log"
printf '%s\n' '[{"repository":"rodri-oliveira-dev/a-public","default_branch":"main","token":"fixture"}]' > "$scratch/invalid.json"
if env -u GH_TOKEN -u GITHUB_TOKEN -u DOTNET_SDK_SYNC_APP_CLIENT_ID \
  -u DOTNET_SDK_SYNC_APP_PRIVATE_KEY DISCOVERED_REPOSITORIES_FILE="$scratch/invalid.json" \
  bash .github/scripts/automation/dotnet-inventory-trust-boundary.sh >/dev/null 2>&1; then
  echo "::error::Inspection accepted an artifact with unexpected fields." >&2
  exit 1
fi

echo "Extracted automation wrappers, shell syntax, discovery privacy and inspection trust boundary passed."
 "$workflow"; then