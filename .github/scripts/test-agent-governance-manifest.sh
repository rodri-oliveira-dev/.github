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

[[ "$(jq '.skills | length' "$manifest")" -gt 0 ]]
[[ "$(jq '[.skills[] | select(.owner.type == "upstream")] | length' "$manifest")" -gt 0 ]]
[[ "$(jq '[.skills[] | select(.distribution.mode == "pull-request-existing")] | length' "$manifest")" -eq "$(jq '[.skills[] | select(.owner.type == "upstream")] | length' "$manifest")" ]]
[[ "$(jq '[.skills[] | select(.distribution.mode == "manual")] | length' "$manifest")" -eq "$(jq '[.skills[] | select(.owner.type == "central")] | length' "$manifest")" ]]
[[ "$(jq '.profiles | length' "$manifest")" -eq 1 ]]

upstream="$(agent_governance_mappings upstream "$manifest")"
distribution="$(agent_governance_mappings distribution "$manifest")"
[[ "$(wc -l <<< "$upstream")" -eq "$(jq '[.skills[] | select(.owner.type == "upstream")] | length' "$manifest")" ]]
[[ "$(wc -l <<< "$distribution")" -eq "$(jq '[.skills[] | select(.distribution.mode == "pull-request-existing")] | length' "$manifest")" ]]
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
assert_invalid unowned-auto '.skills |= map(if .owner.type == "central" then .distribution.mode = "pull-request-existing" else . end)'
assert_invalid profile-source '.profiles[0].source = "agent-governance/profiles/other/AGENTS.md"'
assert_invalid profile-owner-missing 'del(.profiles[0].owner)'
assert_invalid profile-owner-upstream '.profiles[0].owner.type = "upstream"'
assert_invalid profile-owner-extra '.profiles[0].owner.repository = "example/repository"'
assert_invalid profile-owner-type '.profiles[0].owner = "central"'
assert_invalid missing-field 'del(.skills[0].owner)'

# Exercise the real, shared validator against an isolated copy of the catalog.
# Renaming a SKILL.md must fail even when the manifest/path remains unchanged,
# protecting both the required check and the automation preflight.
fixture_catalog="$scratch/catalog"
mkdir -p "$fixture_catalog/agent-governance"
cp "$manifest" "$fixture_catalog/$manifest"
cp "$version" "$fixture_catalog/$version"
mkdir -p "$fixture_catalog/.github/scripts" "$fixture_catalog/agent-governance/profiles/dotnet-library"
cp .github/scripts/validate-agent-governance.rb "$fixture_catalog/.github/scripts/validate-agent-governance.rb"
cp agent-governance/profiles/dotnet-library/profile.yml "$fixture_catalog/agent-governance/profiles/dotnet-library/profile.yml"
while IFS= read -r source; do
  mkdir -p "$fixture_catalog/$(dirname "$source")"
  cp "$source" "$fixture_catalog/$source"
done < <(jq -r '.profiles[].source, .skills[].source' "$manifest")

canonical_skill="$(jq -r '.skills[0].source' "$manifest")"
expected_name="$(jq -r '.skills[0].name' "$manifest")"
grep -Fqx "name: $expected_name" "$fixture_catalog/$canonical_skill"
sed -i "s/^name: $expected_name$/name: renamed-fixture-skill/" "$fixture_catalog/$canonical_skill"
if (
  cd "$fixture_catalog"
  agent_governance_validate_manifest "agent-governance/manifest.json" "agent-governance/VERSION"
) > "$scratch/mismatch-output" 2>&1; then
  echo "::error title=Canonical mismatch accepted::Renamed SKILL.md passed manifest preflight." >&2
  exit 1
fi
grep -Fq 'Skill name mismatch' "$scratch/mismatch-output"
grep -Fq "$canonical_skill" "$scratch/mismatch-output"

if agent_governance_mappings unknown "$manifest" >/dev/null 2>&1; then
  echo "::error::Unknown mapping direction should fail." >&2
  exit 1
fi

echo "Canonical governance manifest and mapping regression harness passed."
