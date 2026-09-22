#!/usr/bin/env bash
# Deterministic manifest and mapping fixtures; no GitHub requests or mutations.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
source .github/scripts/agent-governance-manifest.sh

manifest="agent-governance/manifest.json"
version="agent-governance/VERSION"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
agent_governance_validate_manifest "$manifest" "$version"

[[ "$(jq '.skills | length' "$manifest")" -eq 9 ]]
[[ "$(jq '[.skills[] | select(.owner.type == "upstream")] | length' "$manifest")" -eq 4 ]]
[[ "$(jq '[.skills[] | select(.distribution.mode == "pull-request-existing")] | length' "$manifest")" -eq 4 ]]
[[ "$(jq '[.skills[] | select(.distribution.mode == "manual")] | length' "$manifest")" -eq 5 ]]
[[ "$(jq '.profiles | length' "$manifest")" -eq 1 ]]

upstream="$(agent_governance_mappings upstream "$manifest")"
distribution="$(agent_governance_mappings distribution "$manifest")"
[[ "$(wc -l <<< "$upstream")" -eq 4 ]]
[[ "$(wc -l <<< "$distribution")" -eq 4 ]]
[[ "$(cut -d'|' -f1 <<< "$upstream")" == "$(cut -d'|' -f1 <<< "$distribution")" ]]
while IFS='|' read -r name upstream_path central_path; do
  [[ -s "$central_path" ]]
  [[ "$upstream_path" == ".agents/skills/$name/SKILL.md" ]]
  grep -Fqx "$name|$central_path|$upstream_path" <<< "$distribution"
done <<< "$upstream"

assert_invalid() {
  local name="$1" expression="$2"
  jq "$expression" "$manifest" > "$scratch/$name.json"
  if agent_governance_validate_manifest "$scratch/$name.json" "$version" >/dev/null 2>&1; then
    echo "::error title=Invalid manifest accepted::$name" >&2
    exit 1
  fi
}

assert_invalid schema '.schema_version = 99'
assert_invalid version '.governance_version = "99.0.0"'
assert_invalid duplicate-name '.skills[1].name = .skills[0].name'
assert_invalid duplicate-target '.skills[1].target = .skills[0].target'
assert_invalid missing-source '.skills[0].source = "agent-governance/skills/dotnet/missing/SKILL.md"'
assert_invalid traversal '.skills[0].source = "../outside/SKILL.md"'
assert_invalid bad-mode '.skills[0].distribution.mode = "unknown"'
assert_invalid implicit-automerge '.skills[0].distribution.auto_merge = true'
assert_invalid no-local-authority '.skills[0].distribution.local_authority = false'
assert_invalid wrong-upstream '.skills[0].owner.path = ".agents/skills/other/SKILL.md"'
assert_invalid unowned-auto '.skills[4].distribution.mode = "pull-request-existing"'
assert_invalid profile-source '.profiles[0].source = "agent-governance/profiles/other/AGENTS.md"'
assert_invalid missing-field 'del(.skills[0].owner)'

if agent_governance_mappings unknown "$manifest" >/dev/null 2>&1; then
  echo "::error::Unknown mapping direction should fail." >&2
  exit 1
fi

echo "Canonical governance manifest and mapping regression harness passed."
