#!/usr/bin/env bash
# Extracted from .github/workflows/sync-agent-skills.yml; preserve job-scoped environment and trust boundary.
set -Eeuo pipefail

readonly SYNC_BRANCH="chore/sync-upstream-agent-skills"
readonly PR_TITLE="chore(agent-governance): sync upstream .NET skills"
readonly OWNERSHIP_MARKER="<!-- automation-branch-owner: sync-upstream-agent-skills/v1 -->"
readonly OWNERSHIP_POLICY="$GITHUB_WORKSPACE/.github/scripts/automation-branch-ownership.sh"

if [[ ! -r "$OWNERSHIP_POLICY" ]]; then
  echo "::error title=Missing ownership policy::$OWNERSHIP_POLICY is required before branch mutation."
  exit 1
fi
source "$OWNERSHIP_POLICY"

source "$GITHUB_WORKSPACE/.github/scripts/agent-governance-manifest.sh"
manifest="$GITHUB_WORKSPACE/agent-governance/manifest.json"
agent_governance_validate_manifest "$manifest" "$GITHUB_WORKSPACE/agent-governance/VERSION"
mapping_lines="$(agent_governance_mappings upstream "$manifest")"
mapfile -t mappings <<< "$mapping_lines"

source_sha="$(
  gh api \
    --method GET \
    "repos/$SOURCE_REPO/commits" \
    -f sha="$SOURCE_REF" \
    -f per_page=1 \
    --jq '.[0].sha // empty'
)"

if [[ -z "$source_sha" ]]; then
  echo "::error title=Unknown upstream ref::$SOURCE_REPO does not resolve ref '$SOURCE_REF'."
  exit 1
fi

git fetch origin main --prune
git checkout -B "$SYNC_BRANCH" origin/main

declare -a target_files=()

for mapping in "${mappings[@]}"; do
  IFS='|' read -r expected_name source_path target_path <<< "$mapping"

  if ! response="$(
    gh api \
      --method GET \
      "repos/$SOURCE_REPO/contents/$source_path" \
      -f ref="$SOURCE_REF"
  )"; then
    echo "::error title=Missing upstream skill::$SOURCE_REPO@$SOURCE_REF does not expose $source_path."
    exit 1
  fi

  if [[ "$(jq -r '.type // empty' <<< "$response")" != "file" ]]; then
    echo "::error title=Invalid upstream skill::$source_path is not a file."
    exit 1
  fi

  mkdir -p "$(dirname "$target_path")"
  temp_file="$(mktemp)"
  jq -r '.content' <<< "$response" | tr -d '\n' | base64 --decode > "$temp_file"

  if [[ ! -s "$temp_file" ]]; then
    rm -f "$temp_file"
    echo "::error title=Empty upstream skill::$source_path resolved to an empty file."
    exit 1
  fi

  actual_name="$(sed -n 's/^name: //p' "$temp_file" | head -n 1)"
  description="$(sed -n 's/^description: //p' "$temp_file" | head -n 1)"
  license="$(sed -n 's/^license: //p' "$temp_file" | head -n 1)"

  if [[ "$(head -n 1 "$temp_file")" != "---" ]]; then
    rm -f "$temp_file"
    echo "::error title=Invalid skill frontmatter::$source_path must start with YAML frontmatter."
    exit 1
  fi
  if [[ "$actual_name" != "$expected_name" ]]; then
    rm -f "$temp_file"
    echo "::error title=Unexpected skill name::$source_path declares '$actual_name'; expected '$expected_name'."
    exit 1
  fi
  if [[ -z "$description" ]]; then
    rm -f "$temp_file"
    echo "::error title=Missing skill description::$source_path has no description."
    exit 1
  fi
  if [[ "$license" != "MIT" ]]; then
    rm -f "$temp_file"
    echo "::error title=Unexpected skill license::$source_path must declare license: MIT."
    exit 1
  fi

  mv "$temp_file" "$target_path"
  target_files+=("$target_path")
done

git diff --check

if git diff --quiet -- "${target_files[@]}"; then
  {
    echo "# Agent skill synchronization"
    echo
    echo "No drift detected."
    echo
    printf 'Source: `%s@%s` (`%s`)\n' "$SOURCE_REPO" "$source_sha" "$SOURCE_REF"
  } >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi

mapfile -t changed_paths < <(git diff --name-only -- "${target_files[@]}")

{
  echo "# Agent skill synchronization"
  echo
  printf 'Source: `%s@%s` (`%s`)\n' "$SOURCE_REPO" "$source_sha" "$SOURCE_REF"
  echo
  echo "## Drift"
  echo
  for path in "${changed_paths[@]}"; do
    printf -- '- `%s`\n' "$path"
  done
} >> "$GITHUB_STEP_SUMMARY"

if [[ "$DRY_RUN" == "true" ]]; then
  echo >> "$GITHUB_STEP_SUMMARY"
  echo "Dry run: no branch or Pull Request was changed." >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi

if ! verify_automation_branch_ownership \
  "$TARGET_REPO" \
  "$SYNC_BRANCH" \
  "main" \
  "$OWNERSHIP_MARKER" \
  "$PR_TITLE"; then
  echo "::error title=Automation branch ownership rejected::$AUTOMATION_OWNERSHIP_ERROR"
  exit 1
fi

git config user.name "agent-governance-sync[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -- "${target_files[@]}"
git commit -m "$PR_TITLE"

gh auth setup-git
if [[ "$AUTOMATION_BRANCH_STATE" == "owned" ]]; then
  if ! git push \
    --force-with-lease="refs/heads/$SYNC_BRANCH:$AUTOMATION_BRANCH_SHA" \
    --set-upstream origin "$SYNC_BRANCH"; then
    echo "::error title=Automation branch changed during sync::$TARGET_REPO/$SYNC_BRANCH changed after provenance was verified."
    exit 1
  fi
else
  if ! git push \
    --force-with-lease="refs/heads/$SYNC_BRANCH:" \
    --set-upstream origin "$SYNC_BRANCH"; then
    echo "::error title=Automation branch creation race::$TARGET_REPO/$SYNC_BRANCH was created after provenance verification."
    exit 1
  fi
fi

pr_body="$(mktemp)"
{
  echo "$OWNERSHIP_MARKER"
  echo
  echo "## Automated agent skill synchronization"
  echo
  echo "This Pull Request synchronizes the curated upstream-owned .NET skills into the central agent-governance registry."
  echo
  printf 'Source repository: `%s`\n' "$SOURCE_REPO"
  printf 'Source ref: `%s`\n' "$SOURCE_REF"
  printf 'Source commit: `%s`\n' "$source_sha"
  echo
  echo "### Updated files"
  echo
  for path in "${changed_paths[@]}"; do
    printf -- '- `%s`\n' "$path"
  done
  echo
  echo "### Synchronization policy"
  echo
  echo "- Only the four explicitly allowlisted skills are synchronized."
  echo "- Their contents are copied byte-for-byte from the upstream repository."
  echo "- New upstream skills are not discovered or imported automatically."
  echo "- The automation-owned branch may be force-updated by later synchronization runs."
  echo "- Auto-merge is intentionally disabled; governance changes require review."
  echo
  echo "### Validation"
  echo
  echo "- Upstream files were resolved through the GitHub API."
  echo "- Required skill frontmatter, names, descriptions, and MIT license were validated before commit."
  echo "- `git diff --check` passed."
  echo "- The repository's Agent governance validation workflow remains the merge gate."
} > "$pr_body"

if [[ "$AUTOMATION_BRANCH_STATE" == "owned" ]]; then
  gh pr edit "$AUTOMATION_PR_NUMBER" \
    --repo "$TARGET_REPO" \
    --title "$PR_TITLE" \
    --body-file "$pr_body"
  pr_url="$(gh pr view "$AUTOMATION_PR_NUMBER" --repo "$TARGET_REPO" --json url --jq '.url')"
  action="updated"
else
  pr_url="$(
    gh pr create \
      --repo "$TARGET_REPO" \
      --base main \
      --head "$SYNC_BRANCH" \
      --title "$PR_TITLE" \
      --body-file "$pr_body"
  )"
  action="created"
fi

rm -f "$pr_body"

{
  echo
  printf 'Pull Request %s: %s\n' "$action" "$pr_url"
} >> "$GITHUB_STEP_SUMMARY"
