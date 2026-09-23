#!/usr/bin/env bash
# Fail closed when a PR changes the distributed governance contract without a
# strictly increasing canonical VERSION. Run from the repository root.
set -Eeuo pipefail

base_sha="${1:?Usage: check-agent-governance-version.sh <PR-base-commit-SHA>}"
version_file="agent-governance/VERSION"
manifest_file="agent-governance/manifest.json"
profile_file="agent-governance/profiles/dotnet-library/profile.yml"

if [[ ! "$base_sha" =~ ^[0-9a-f]{40}$ ]] ||
  ! git cat-file -e "$base_sha^{commit}" 2>/dev/null ||
  ! git merge-base --is-ancestor "$base_sha" HEAD; then
  echo "::error title=Invalid governance comparison base::Expected an existing ancestor commit SHA for the PR base." >&2
  exit 1
fi

base_version="$(git show "$base_sha:$version_file")" || {
  echo "::error title=Missing baseline version::Cannot read the canonical VERSION at the PR base." >&2
  exit 1
}
[[ -s "$version_file" && -s "$manifest_file" && -s "$profile_file" ]] || {
  echo "::error title=Missing governance contract::VERSION, manifest and profile must all exist." >&2
  exit 1
}
current_version="$(cat "$version_file")"
semver='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
if [[ ! "$base_version" =~ $semver || ! "$current_version" =~ $semver ]]; then
  echo "::error title=Invalid governance SemVer::Both baseline and current VERSION must be strict MAJOR.MINOR.PATCH without leading zeros." >&2
  exit 1
fi

# Independent of whether the PR changes contractual content, a version bump
# must be coherent across the canonical source and its declarative consumers.
if ! jq -e --arg v "$current_version" '.governance_version == $v' "$manifest_file" >/dev/null; then
  echo "::error title=Governance version mismatch::Manifest governance_version differs from VERSION." >&2
  exit 1
fi
# Profile fields are YAML data, not mandatory literal formatting.
# The catalog validator additionally checks uniqueness, schema and references.
if ! ruby -rpsych -e '
  data = Psych.safe_load(File.read(ARGV.fetch(0)), permitted_classes: [],
                         permitted_symbols: [], aliases: false)
  exit(data.is_a?(Hash) && data["governance_version"] == ARGV.fetch(1) ? 0 : 1)
' "$profile_file" "$current_version"; then
  echo "::error title=Governance version mismatch::Profile governance_version differs from VERSION." >&2
  exit 1
fi

scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
contract_changed=false
declare -a contract_paths=()

# Compare the merge result (HEAD) against the exact PR base. Renames count as
# deletions and additions; new/removed files count as contract changes.
while IFS= read -r -d '' path; do
  case "$path" in
    agent-governance/VERSION|agent-governance/README.md)
      continue ;;
    "$manifest_file")
      if ! git show "$base_sha:$manifest_file" > "$scratch/base-manifest.json" 2>/dev/null ||
        ! jq -S 'del(.governance_version)' "$scratch/base-manifest.json" > "$scratch/base-manifest.normalized" ||
        ! jq -S 'del(.governance_version)' "$manifest_file" > "$scratch/current-manifest.normalized" ||
        ! cmp -s "$scratch/base-manifest.normalized" "$scratch/current-manifest.normalized"; then
        contract_changed=true
        contract_paths+=("$path")
      fi ;;
    "$profile_file")
      if ! git show "$base_sha:$profile_file" > "$scratch/base-profile.yml" 2>/dev/null; then
        contract_changed=true
        contract_paths+=("$path")
      else
        # Compare the effective YAML mappings, ignoring only the derived version;
        # comments, quoting and field order are not contract changes.
        profile_to_json() {
          ruby -rjson -rpsych -e '
            data = Psych.safe_load(File.read(ARGV.fetch(0)), permitted_classes: [],
                                   permitted_symbols: [], aliases: false)
            abort "Invalid governance profile YAML" unless data.is_a?(Hash)
            data.delete("governance_version")
            # Canonicalize every mapping, including mappings nested in arrays.
            # Preserve array ordering and scalar types: those are contractual.
            canonicalize = lambda do |value|
              case value
              when Hash
                value.sort_by { |key, _| key.to_s }
                     .to_h { |key, item| [key, canonicalize.call(item)] }
              when Array
                value.map { |item| canonicalize.call(item) }
              else
                value
              end
            end
            puts JSON.generate(canonicalize.call(data))
          ' "$1"
        }
        if ! profile_to_json "$scratch/base-profile.yml" > "$scratch/base-profile.normalized" ||
          ! profile_to_json "$profile_file" > "$scratch/current-profile.normalized"; then
          contract_changed=true
          contract_paths+=("$path")
          continue
        fi
        if ! cmp -s "$scratch/base-profile.normalized" "$scratch/current-profile.normalized"; then
          contract_changed=true
          contract_paths+=("$path")
        fi
      fi ;;
    agent-governance/*)
      # Skills, AGENTS files, base policy, and all other governance resources
      # affect consumers. A wording-only SKILL.md edit is conservatively
      # contractual; only standalone registry README.md is exempt.
      contract_changed=true
      contract_paths+=("$path") ;;
  esac
done < <(git diff --name-only --no-renames -z "$base_sha" HEAD -- agent-governance/)

if [[ "$current_version" != "$base_version" ]]; then
  if ! python3 - "$base_version" "$current_version" <<'PY'
import sys
base, current = [tuple(map(int, v.split("."))) for v in sys.argv[1:]]
sys.exit(0 if current > base else 1)
PY
  then
    echo "::error title=Governance version regression::VERSION must increase from $base_version, not become $current_version." >&2
    exit 1
  fi
fi

if [[ "$contract_changed" == "true" && "$current_version" == "$base_version" ]]; then
  printf '::error title=Governance contract changed without bump::Contract changed while VERSION remains %s. Update VERSION, manifest and profile together.\n' "$current_version" >&2
  printf 'Contract path: %s\n' "${contract_paths[@]}" >&2
  exit 1
fi

if [[ "$contract_changed" == "true" ]]; then
  printf 'Governance contract changed: %s -> %s (%s path(s)).\n' "$base_version" "$current_version" "${#contract_paths[@]}"
else
  printf 'Governance contract unchanged; no bump required (base %s, current %s).\n' "$base_version" "$current_version"
fi
