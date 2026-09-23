#!/usr/bin/env bash
# Reproducible end-to-end policy tests in a temporary, self-contained git repo.
set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
gate="$root/.github/scripts/check-agent-governance-version.sh"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
repo="$tmp/fixture"
git init -q -b main "$repo"
git -C "$repo" config user.name fixture
git -C "$repo" config user.email fixture@example.invalid
mkdir -p "$repo/agent-governance/profiles/dotnet-library" "$repo/agent-governance/skills/dotnet/example" "$repo/docs"
printf '1.1.0\n' > "$repo/agent-governance/VERSION"
printf '{"schema_version":1,"governance_version":"1.1.0","skills":[{"name":"example"}]}\n' > "$repo/agent-governance/manifest.json"
printf 'profile: dotnet-library\ngovernance_version: 1.1.0\nstatus: active\n' > "$repo/agent-governance/profiles/dotnet-library/profile.yml"
printf '%s\n' '---' 'name: example' '---' 'Initial instruction.' > "$repo/agent-governance/skills/dotnet/example/SKILL.md"
printf 'Registry documentation.\n' > "$repo/agent-governance/README.md"
printf 'Project documentation.\n' > "$repo/docs/guide.md"
git -C "$repo" add -A
git -C "$repo" commit -qm 'fixture baseline'
base="$(git -C "$repo" rev-parse HEAD)"

reset_fixture() {
  git -C "$repo" reset --hard -q "$base"
  git -C "$repo" clean -fdq
}
set_version() {
  local v="$1"
  printf '%s\n' "$v" > "$repo/agent-governance/VERSION"
  sed -i -E "s/^governance_version: .*/governance_version: $v/" "$repo/agent-governance/profiles/dotnet-library/profile.yml"
  jq --arg version "$v" '.governance_version = $version' "$repo/agent-governance/manifest.json" > "$tmp/manifest.new"
  mv "$tmp/manifest.new" "$repo/agent-governance/manifest.json"
}
assert_gate() {
  local label="$1" expected="$2" substring="$3" result
  git -C "$repo" add -A
  if ! git -C "$repo" diff --cached --quiet; then
    git -C "$repo" commit -qm "$label"
  fi
  if (cd "$repo" && bash "$gate" "$base") > "$tmp/result.log" 2>&1; then
    result=success
  else
    result=failure
  fi
  if [[ "$result" != "$expected" ]] || ! grep -Fq "$substring" "$tmp/result.log"; then
    echo "::error title=Version policy regression::$label: expected $expected containing '$substring', got $result." >&2
    cat "$tmp/result.log" >&2
    exit 1
  fi
}

reset_fixture
assert_gate identical success 'Governance contract unchanged'
reset_fixture
printf 'Extra explanation.\n' >> "$repo/agent-governance/README.md"
printf 'More instructions for readers.\n' >> "$repo/docs/guide.md"
assert_gate documentation-only success 'no bump required'
reset_fixture
printf 'New mandatory instruction.\n' >> "$repo/agent-governance/skills/dotnet/example/SKILL.md"
assert_gate skill-without-bump failure 'contract changed without bump'
reset_fixture
printf 'Base policy.\n' > "$repo/agent-governance/base.md"
assert_gate base-policy-without-bump failure 'contract changed without bump'
reset_fixture
mkdir -p "$repo/agent-governance/skills/dotnet/added"
printf 'New skill.\n' > "$repo/agent-governance/skills/dotnet/added/SKILL.md"
assert_gate skill-added-without-bump failure 'contract changed without bump'
reset_fixture
mv "$repo/agent-governance/skills/dotnet/example/SKILL.md" "$repo/agent-governance/skills/dotnet/example/MOVED.md"
assert_gate skill-renamed-without-bump failure 'contract changed without bump'
reset_fixture
jq -S '.' "$repo/agent-governance/manifest.json" > "$tmp/manifest.new"
mv "$tmp/manifest.new" "$repo/agent-governance/manifest.json"
assert_gate json-formatting-only success 'no bump required'
reset_fixture
jq '.skills[0].name = "changed"' "$repo/agent-governance/manifest.json" > "$tmp/manifest.new"
mv "$tmp/manifest.new" "$repo/agent-governance/manifest.json"
assert_gate manifest-contract-without-bump failure 'contract changed without bump'
reset_fixture
sed -i 's/profile: dotnet-library/profile: "dotnet-library"/' "$repo/agent-governance/profiles/dotnet-library/profile.yml"
printf '# Formatting-only comment.\n' >> "$repo/agent-governance/profiles/dotnet-library/profile.yml"
assert_gate profile-yaml-formatting-only success 'no bump required'
reset_fixture
sed -i 's/^status: active/status: paused/' "$repo/agent-governance/profiles/dotnet-library/profile.yml"
assert_gate profile-contract-without-bump failure 'contract changed without bump'
reset_fixture
set_version 1.1.1
printf 'Clarified instruction.\n' >> "$repo/agent-governance/skills/dotnet/example/SKILL.md"
assert_gate patch-with-contract success 'Governance contract changed: 1.1.0 -> 1.1.1'
reset_fixture
set_version 1.2.0
jq '.skills += [{"name":"added"}]' "$repo/agent-governance/manifest.json" > "$tmp/manifest.new"
mv "$tmp/manifest.new" "$repo/agent-governance/manifest.json"
assert_gate minor-with-contract success 'Governance contract changed: 1.1.0 -> 1.2.0'
reset_fixture
set_version 2.0.0
sed -i 's/^status: active/status: paused/' "$repo/agent-governance/profiles/dotnet-library/profile.yml"
assert_gate major-with-contract success 'Governance contract changed: 1.1.0 -> 2.0.0'
reset_fixture
set_version 1.1.1
assert_gate version-fields-only success 'Governance contract unchanged'
reset_fixture
set_version 1.0.9
assert_gate downgrade failure 'version regression'
reset_fixture
set_version 1.1.0
jq '.governance_version = "1.2.0"' "$repo/agent-governance/manifest.json" > "$tmp/manifest.new"
mv "$tmp/manifest.new" "$repo/agent-governance/manifest.json"
assert_gate inconsistent-manifest failure 'Manifest governance_version differs'
reset_fixture
set_version 1.1.1
sed -i 's/^governance_version: .*/governance_version: 1.1.0/' "$repo/agent-governance/profiles/dotnet-library/profile.yml"
assert_gate inconsistent-profile failure 'Profile governance_version differs'
reset_fixture
set_version 01.2.0
assert_gate malformed-semver failure 'strict MAJOR.MINOR.PATCH'
reset_fixture
printf 'Automation-only change.\n' > "$repo/some-automation-file.sh"
assert_gate unrelated-source success 'no bump required'
reset_fixture
if (cd "$repo" && bash "$gate" "1111111111111111111111111111111111111111") > "$tmp/result.log" 2>&1; then
  echo "::error::Unknown base commit must fail closed." >&2
  exit 1
fi
grep -Fq 'Invalid governance comparison base' "$tmp/result.log"

echo "Governance version gate: docs, changes, renames, SemVer, coherence and invalid baselines passed."
