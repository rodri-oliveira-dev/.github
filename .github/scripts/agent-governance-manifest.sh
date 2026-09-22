#!/usr/bin/env bash
# Canonical, fail-closed catalog contract shared by validation and automation.
# Requires jq. Never evaluates manifest values as shell code.
agent_governance_validate_manifest() {
  local manifest="${1:-agent-governance/manifest.json}"
  local version_file="${2:-agent-governance/VERSION}"
  local version
  [[ -s "$manifest" && -s "$version_file" ]] || {
    echo "::error title=Missing governance manifest::Manifest or VERSION is missing." >&2
    return 1
  }
  version="$(tr -d '[:space:]' < "$version_file")"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "::error title=Invalid governance version::VERSION must use MAJOR.MINOR.PATCH." >&2
    return 1
  }
  if ! jq -e --arg version "$version" '
    def safe_name: type == "string" and test("^[a-z0-9][a-z0-9-]*$");
    def safe_file: type == "string" and test("^[a-zA-Z0-9._/-]+$") and
      (split("/") | all(. != "" and . != "." and . != ".."));
    def policy($mode):
      (.distribution | type == "object" and
        .mode == $mode and .auto_merge == false and .local_authority == true);
    type == "object" and
    .schema_version == 1 and .governance_version == $version and
    (.profiles | type == "array" and length == 1 and
      all(.[]; (.name | safe_name) and
        (.source | safe_file) and (.target == "AGENTS.md") and
        (.source == ("agent-governance/profiles/" + .name + "/AGENTS.md")) and policy("manual"))) and
    (.profiles[0].name == "dotnet-library") and
    (.skills | type == "array" and length > 0 and
      all(.[];
        (.name | safe_name) and .profile == "dotnet-library" and
        (.source | safe_file) and
        (.source | test("^agent-governance/skills/(dotnet|dotnet-library)/[a-z0-9-]+/SKILL[.]md$")) and
        (.source | split("/")[-2] == .name) and
        (.target == (".agents/skills/" + .name + "/SKILL.md")) and
        (.owner | type == "object") and
        (if .owner.type == "upstream" then
          .owner.repository == "rodri-oliveira-dev/dotnet-library-template" and
          .owner.path == .target and policy("pull-request-existing")
        else
          .owner.type == "central" and
          (.owner | keys == ["type"]) and policy("manual")
        end) and
        (.distribution | keys | sort == ["auto_merge", "local_authority", "mode"])
      ) and
      ([.[].name] | unique | length) == length and
      ([.[].source] | unique | length) == length and
      ([.[].target] | unique | length) == length)
  ' "$manifest" >/dev/null; then
    echo "::error title=Invalid governance manifest::Invalid schema, version, paths, ownership or distribution policy." >&2
    return 1
  fi

  local source
  while IFS= read -r source; do
    if [[ ! -s "$source" ]]; then
      echo "::error title=Missing governance source::$source is missing or empty." >&2
      return 1
    fi
  done < <(jq -r '.profiles[].source, .skills[].source' "$manifest")
}

# Output exactly the allowlisted managed mappings. The caller must validate
# before using the result; no mutation should occur if validation fails.
agent_governance_mappings() {
  local direction="$1" manifest="${2:-agent-governance/manifest.json}"
  case "$direction" in
    upstream)
      jq -er '
        [.skills[] | select(.owner.type == "upstream" and .distribution.mode == "pull-request-existing")
          | [.name, .owner.path, .source] | join("|")] | if length > 0 then .[] else error("no upstream mappings") end
      ' "$manifest"
      ;;
    distribution)
      jq -er '
        [.skills[] | select(.distribution.mode == "pull-request-existing")
          | [.name, .source, .target] | join("|")] | if length > 0 then .[] else error("no consumer mappings") end
      ' "$manifest"
      ;;
    *)
      echo "::error::Unknown manifest mapping direction: $direction" >&2
      return 2
      ;;
  esac
}
