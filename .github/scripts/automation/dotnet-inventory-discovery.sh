#!/usr/bin/env bash
# Extracted from .github/workflows/dotnet-repository-inventory.yml; preserve job-scoped environment and trust boundary.
set -Eeuo pipefail

raw_repositories="$(mktemp)"
discovery_dir="$RUNNER_TEMP/dotnet-repository-discovery"
sanitized_repositories="$discovery_dir/repositories.json"

mkdir -p "$discovery_dir"
trap 'rm -f "$raw_repositories"' EXIT

gh api --paginate "/installation/repositories?per_page=100" \
  --jq '.repositories[]' \
  > "$raw_repositories"

jq -s --arg owner "$OWNER" '
  [
    .[]
    | select(.owner.login == $owner)
    | select((.visibility // (if .private then "private" else "public" end)) == "public")
    | select(.archived == false)
    | select(.fork == false)
    | {
        repository: .full_name,
        default_branch: (.default_branch // "")
      }
  ]
  | sort_by(.repository)
' "$raw_repositories" > "$sanitized_repositories"

repository_count="$(jq 'length' "$sanitized_repositories")"

{
  echo "# .NET repository inventory discovery"
  echo
  printf 'Eligible public repositories: %s\n' "$repository_count"
  echo
  echo "Only repository name and default branch are transferred to the inspection job through a short-lived artifact."
} >> "$GITHUB_STEP_SUMMARY"
