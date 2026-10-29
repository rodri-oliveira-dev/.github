#!/usr/bin/env bash
set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
policy="$root/.github/scripts/automation-branch-ownership.sh"
sdk="$root/.github/scripts/automation/dotnet-sdk-sync.sh"
distribution="$root/.github/scripts/automation/distribute-agent-skills.sh"
upstream="$root/.github/scripts/automation/sync-agent-skills.sh"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
mkdir -p "$scratch/bin"

cat > "$scratch/bin/gh" <<'GH_MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$FAKE_CALLS"
case "$*" in
  *"/pulls/"*"/files"*) printf '%s\n' "${FAKE_FILES_JSON:-[]}" ;;
  *"/git/matching-refs/"*"fixture-v1-managed"*) printf '%s\n' "${FAKE_RECOVERY_REFS_JSON:-[]}" ;;
  *"/git/matching-refs/"*) printf '%s\n' "${FAKE_REFS_JSON:-[]}" ;;
  *"/pulls"*"fixture-v1-managed"*) printf '%s\n' "${FAKE_RECOVERY_PRS_JSON:-[]}" ;;
  *"/pulls"*) printf '%s\n' "${FAKE_PRS_JSON:-[]}" ;;
  *) echo "unexpected fake gh invocation: $*" >&2; exit 1 ;;
esac
GH_MOCK
chmod +x "$scratch/bin/gh"
export PATH="$scratch/bin:$PATH"
export FAKE_CALLS="$scratch/calls"

source "$policy"

repo="rodri-oliveira-dev/fixture"
branch="chore/fixture"
recovery_branch="chore/fixture-fixture-v1-managed"
base="main"
marker="<!-- automation-branch-owner: fixture/v1 -->"
title="chore: fixture automation"
sha="1111111111111111111111111111111111111111"
other_sha="2222222222222222222222222222222222222222"

refs() {
  jq -cn --arg branch "$1" --arg sha "$2" '[{ref:("refs/heads/" + $branch),object:{sha:$sha}}]'
}

pr() {
  local state="$1" head_sha="$2" body="$3" pr_title="${4:-$title}"
  local author_type="${5:-Bot}" merged_at="${6:-}"
  jq -cn --arg repo "$repo" --arg branch "$branch" --arg base "$base" \
    --arg sha "$head_sha" --arg body "$body" --arg title "$pr_title" \
    --arg state "$state" --arg author "$author_type" --arg merged "$merged_at" '[{
      number:42,html_url:"https://github.com/example/fixture/pull/42",
      state:$state,merged_at:(if $merged == "" then null else $merged end),
      title:$title,body:$body,user:{login:"fixture[bot]",type:$author},
      head:{sha:$sha,ref:$branch,repo:{full_name:$repo}},base:{ref:$base}
    }]'
}

reset_fixtures() {
  : > "$FAKE_CALLS"
  FAKE_REFS_JSON='[]'
  FAKE_PRS_JSON='[]'
  FAKE_RECOVERY_REFS_JSON='[]'
  FAKE_RECOVERY_PRS_JSON='[]'
  FAKE_FILES_JSON="$(jq -cn '[{filename:"global.json"}]')"
  export FAKE_REFS_JSON FAKE_PRS_JSON FAKE_RECOVERY_REFS_JSON FAKE_RECOVERY_PRS_JSON FAKE_FILES_JSON
}

# 1. A missing branch is available without consulting PR history.
reset_fixtures
verify_automation_branch_ownership "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_BRANCH_STATE" == "absent" ]]
[[ "$(wc -l < "$FAKE_CALLS")" -eq 1 ]]

# A branch with no PR origin is classified but never treated as owned.
reset_fixtures
FAKE_REFS_JSON="$(refs "$branch" "$sha")"
export FAKE_REFS_JSON
verify_automation_branch_ownership "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_BRANCH_STATE" == "unproven" ]]

# 2. An open, marked, bot-authored PR with exact provenance is reusable.
reset_fixtures
FAKE_REFS_JSON="$(refs "$branch" "$sha")"
FAKE_PRS_JSON="$(pr open "$sha" "$marker")"
export FAKE_REFS_JSON FAKE_PRS_JSON
verify_automation_branch_ownership "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_BRANCH_STATE" == "owned" && "$AUTOMATION_BRANCH_SHA" == "$sha" ]]
[[ "$AUTOMATION_PR_NUMBER" == "42" ]]

# 3. A branch left by a merged PR is historical, never directly reusable.
reset_fixtures
FAKE_REFS_JSON="$(refs "$branch" "$sha")"
FAKE_PRS_JSON="$(pr closed "$sha" "$marker" "$title" Bot '2026-01-01T00:00:00Z')"
export FAKE_REFS_JSON FAKE_PRS_JSON
verify_automation_branch_ownership "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_BRANCH_STATE" == "historical_merged" ]]

# 4. A deliberately closed, unmerged PR remains closed and is classified.
reset_fixtures
FAKE_REFS_JSON="$(refs "$branch" "$sha")"
FAKE_PRS_JSON="$(pr closed "$sha" "$marker")"
export FAKE_REFS_JSON FAKE_PRS_JSON
verify_automation_branch_ownership "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_BRANCH_STATE" == "historical_closed" ]]

# A closed or merged PR with a later branch commit is historical, not an
# unsafe open PR. Preserve the old ref and select an absent recovery branch.
for historical_merged in false true; do
  reset_fixtures
  FAKE_REFS_JSON="$(refs "$branch" "$other_sha")"
  if [[ "$historical_merged" == "true" ]]; then
    FAKE_PRS_JSON="$(pr closed "$sha" "$marker" "$title" Bot '2026-01-01T00:00:00Z')"
  else
    FAKE_PRS_JSON="$(pr closed "$sha" "$marker")"
  fi
  export FAKE_REFS_JSON FAKE_PRS_JSON
  verify_automation_branch_ownership "$repo" "$branch" "$base" "$marker" "$title" "global.json"
  [[ "$AUTOMATION_BRANCH_STATE" == "historical_modified" ]]
  select_automation_branch "$repo" "$branch" "$base" "$marker" "$title" "global.json"
  [[ "$AUTOMATION_BRANCH_NAME" == "$recovery_branch" && "$AUTOMATION_BRANCH_STATE" == "absent" ]]
  [[ "$AUTOMATION_RECOVERY_USED" == "true" ]]
done

# A changed branch with an OPEN PR remains unsafe and blocking.
reset_fixtures
FAKE_REFS_JSON="$(refs "$branch" "$other_sha")"
FAKE_PRS_JSON="$(pr open "$sha" "$marker")"
export FAKE_REFS_JSON FAKE_PRS_JSON
verify_automation_branch_ownership "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_BRANCH_STATE" == "modified" ]]
if select_automation_branch "$repo" "$branch" "$base" "$marker" "$title" "global.json"; then
  echo "::error::A changed open PR was incorrectly recovered." >&2
  exit 1
fi

# 5. A legacy open PR needs bot identity, compatible title and only managed files.
reset_fixtures
FAKE_REFS_JSON="$(refs "$branch" "$sha")"
FAKE_PRS_JSON="$(pr open "$sha" '')"
FAKE_FILES_JSON="$(jq -cn '[{filename:"global.json"}]')"
export FAKE_REFS_JSON FAKE_PRS_JSON FAKE_FILES_JSON
verify_automation_branch_ownership "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_BRANCH_STATE" == "owned_legacy" ]]

# Full allowlists remain authoritative even when only one managed path
# currently differs from the consumer's default branch.
reset_fixtures
FAKE_REFS_JSON="$(refs "$branch" "$sha")"
FAKE_PRS_JSON="$(pr open "$sha" "$marker")"
FAKE_FILES_JSON="$(jq -cn '[{filename:"global.json"},{filename:"managed/skill.md"}]')"
export FAKE_REFS_JSON FAKE_PRS_JSON FAKE_FILES_JSON
verify_automation_branch_ownership "$repo" "$branch" "$base" "$marker" "$title" 
reset_fixtures
FAKE_REFS_JSON="$(refs "$branch" "$sha")"
FAKE_PRS_JSON="$(pr open "$sha" "$marker")"
FAKE_FILES_JSON="$(jq -cn '[{filename:"global.json"},{filename:"README.md"}]')"
export FAKE_REFS_JSON FAKE_PRS_JSON FAKE_FILES_JSON
verify_automation_branch_ownership "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_BRANCH_STATE" == "modified" ]]
if select_automation_branch "$repo" "$branch" "$base" "$marker" "$title" "global.json"; then
  echo "::error::A manually modified open PR was recovered into a duplicate PR branch." >&2
  exit 1
fi
[[ "$AUTOMATION_BRANCH_STATE" == "modified" ]]

# 7. Two concurrent open PR references are a conflict.
reset_fixtures
FAKE_REFS_JSON="$(refs "$branch" "$sha")"
FAKE_PRS_JSON="$(jq -cn --argjson one "$(pr open "$sha" "$marker")" '$one + ($one | map(.number = 43))')"
export FAKE_REFS_JSON FAKE_PRS_JSON
verify_automation_branch_ownership "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_BRANCH_STATE" == "conflict_open" ]]
if select_automation_branch "$repo" "$branch" "$base" "$marker" "$title" "global.json"; then
  echo "::error::Concurrent open PRs were recovered into another PR branch." >&2
  exit 1
fi

# 8 and 11. Recovery is deterministic, and a later run reuses its proven PR.
reset_fixtures
FAKE_REFS_JSON="$(refs "$branch" "$sha")"
FAKE_PRS_JSON="$(pr closed "$sha" "$marker")"
export FAKE_REFS_JSON FAKE_PRS_JSON
select_automation_branch "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_RECOVERY_USED" == "true" ]]
[[ "$AUTOMATION_BRANCH_NAME" == "$recovery_branch" && "$AUTOMATION_BRANCH_STATE" == "absent" ]]

FAKE_RECOVERY_REFS_JSON="$(refs "$recovery_branch" "$other_sha")"
FAKE_RECOVERY_PRS_JSON="$(pr open "$other_sha" "$marker" | jq --arg branch "$recovery_branch" '.[].head.ref = $branch')"
export FAKE_RECOVERY_REFS_JSON FAKE_RECOVERY_PRS_JSON
select_automation_branch "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_BRANCH_NAME" == "$recovery_branch" && "$AUTOMATION_BRANCH_STATE" == "owned" ]]
[[ "$AUTOMATION_PR_NUMBER" == "42" ]]

# 9. A PR failure after push is retained and reported; no cleanup/delete exists.
grep -Fq 'branch was pushed but PR creation failed; branch retained for manual recovery' "$distribution"
grep -Fq 'was pushed but a PR could not be opened; the branch was retained for safe recovery' "$sdk"
if grep -Eq -- '--method[[:space:]]+DELETE|git[[:space:]]+push[^[:cntrl:]]+--delete' "$policy" "$sdk" "$distribution"; then
  echo "::error::Automation branch cleanup must never delete historical refs." >&2
  exit 1
fi

# 10. An exact-head lease rejects a branch changed after verification.
remote="$scratch/remote.git"
seed="$scratch/seed"
racer="$scratch/racer"
git init --quiet --bare "$remote"
git clone --quiet "$remote" "$seed"
git -C "$seed" config user.name fixture
git -C "$seed" config user.email fixture@example.invalid
echo base > "$seed/file.txt"
git -C "$seed" add file.txt
git -C "$seed" commit --quiet -m base
git -C "$seed" push --quiet origin HEAD:main
git -C "$seed" checkout --quiet -b "$branch"
echo owned >> "$seed/file.txt"
git -C "$seed" commit --quiet -am owned
git -C "$seed" push --quiet origin "HEAD:refs/heads/$branch"
captured_sha="$(git ls-remote "$remote" "refs/heads/$branch" | awk '{print $1}')"
git clone --quiet --branch "$branch" "$remote" "$racer"
git -C "$racer" config user.name racer
git -C "$racer" config user.email racer@example.invalid
echo race >> "$racer/file.txt"
git -C "$racer" commit --quiet -am race
git -C "$racer" push --quiet origin "HEAD:refs/heads/$branch"
echo candidate >> "$seed/file.txt"
git -C "$seed" commit --quiet -am candidate
if git -C "$seed" push --quiet --force-with-lease="refs/heads/$branch:$captured_sha" \
  origin "HEAD:refs/heads/$branch" 2>/dev/null; then
  echo "::error::A stale exact-head lease overwrote a changed branch." >&2
  exit 1
fi

# 12. Dry-run exits before ownership lookup, git setup, pushes or PR mutation.
dry_run_line="$(grep -n 'if \[\[ "$DRY_RUN" == "true" \]\]' "$sdk" | tail -n 1 | cut -d: -f1)"
selection_line="$(grep -n 'select_automation_branch' "$sdk" | tail -n 1 | cut -d: -f1)"
[[ "$dry_run_line" -lt "$selection_line" ]]
dry_run_line="$(grep -n 'if \[\[ "$DRY_RUN" == "true" \]\]' "$distribution" | tail -n 1 | cut -d: -f1)"
selection_line="$(grep -n 'select_automation_branch' "$distribution" | tail -n 1 | cut -d: -f1)"
[[ "$dry_run_line" -lt "$selection_line" ]]

# Mutation scope and lease contracts remain narrow.
grep -Fq 'git -C "$sdk_worktree" add -- "$GLOBAL_JSON_PATH"' "$sdk"
grep -Fq 'git -C "$worktree" add -- "${changed_targets[@]}"' "$distribution"
grep -Fq -- '--force-with-lease="refs/heads/$active_branch:$branch_parent_sha"' "$sdk"
grep -Fq -- '--force-with-lease="refs/heads/$active_branch:$AUTOMATION_BRANCH_SHA"' "$distribution"
if grep -Eq 'git[[:space:]].*push[[:space:]].*--force([[:space:]]|$)' "$sdk" "$distribution"; then
  echo "::error::Unprotected force push detected." >&2
  exit 1
fi

# All callers use the selection contract and include all managed paths.
grep -Fq 'managed_consumer_path' "$distribution"
grep -Fq 'if ! select_automation_branch' "$upstream"
grep -Fq 'managed_paths=' "$upstream"
grep -Fq 'target_files[@]' "$upstream"
grep -Fq '"$managed_paths"; then' "$upstream"
grep -Fq '"$AUTOMATION_BRANCH_STATE" == "owned_legacy"' "$upstream"
grep -Fq 'origin "HEAD:refs/heads/$active_branch"' "$upstream"
grep -Fq -- '--head "$active_branch"' "$upstream"

echo "Automation ownership, orphan recovery, idempotency, race and dry-run regressions passed."
global.json\nmanaged/skill.md'
[[ "$AUTOMATION_BRANCH_STATE" == "owned" ]]
verify_automation_branch_ownership "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_BRANCH_STATE" == "modified" ]]

# 6. Manual changes outside the managed file set invalidate ownership.
reset_fixtures
FAKE_REFS_JSON="$(refs "$branch" "$sha")"
FAKE_PRS_JSON="$(pr open "$sha" "$marker")"
FAKE_FILES_JSON="$(jq -cn '[{filename:"global.json"},{filename:"README.md"}]')"
export FAKE_REFS_JSON FAKE_PRS_JSON FAKE_FILES_JSON
verify_automation_branch_ownership "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_BRANCH_STATE" == "modified" ]]
if select_automation_branch "$repo" "$branch" "$base" "$marker" "$title" "global.json"; then
  echo "::error::A manually modified open PR was recovered into a duplicate PR branch." >&2
  exit 1
fi
[[ "$AUTOMATION_BRANCH_STATE" == "modified" ]]

# 7. Two concurrent open PR references are a conflict.
reset_fixtures
FAKE_REFS_JSON="$(refs "$branch" "$sha")"
FAKE_PRS_JSON="$(jq -cn --argjson one "$(pr open "$sha" "$marker")" '$one + ($one | map(.number = 43))')"
export FAKE_REFS_JSON FAKE_PRS_JSON
verify_automation_branch_ownership "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_BRANCH_STATE" == "conflict_open" ]]
if select_automation_branch "$repo" "$branch" "$base" "$marker" "$title" "global.json"; then
  echo "::error::Concurrent open PRs were recovered into another PR branch." >&2
  exit 1
fi

# 8 and 11. Recovery is deterministic, and a later run reuses its proven PR.
reset_fixtures
FAKE_REFS_JSON="$(refs "$branch" "$sha")"
FAKE_PRS_JSON="$(pr closed "$sha" "$marker")"
export FAKE_REFS_JSON FAKE_PRS_JSON
select_automation_branch "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_RECOVERY_USED" == "true" ]]
[[ "$AUTOMATION_BRANCH_NAME" == "$recovery_branch" && "$AUTOMATION_BRANCH_STATE" == "absent" ]]

FAKE_RECOVERY_REFS_JSON="$(refs "$recovery_branch" "$other_sha")"
FAKE_RECOVERY_PRS_JSON="$(pr open "$other_sha" "$marker" | jq --arg branch "$recovery_branch" '.[].head.ref = $branch')"
export FAKE_RECOVERY_REFS_JSON FAKE_RECOVERY_PRS_JSON
select_automation_branch "$repo" "$branch" "$base" "$marker" "$title" "global.json"
[[ "$AUTOMATION_BRANCH_NAME" == "$recovery_branch" && "$AUTOMATION_BRANCH_STATE" == "owned" ]]
[[ "$AUTOMATION_PR_NUMBER" == "42" ]]

# 9. A PR failure after push is retained and reported; no cleanup/delete exists.
grep -Fq 'branch was pushed but PR creation failed; branch retained for manual recovery' "$distribution"
grep -Fq 'was pushed but a PR could not be opened; the branch was retained for safe recovery' "$sdk"
if grep -Eq -- '--method[[:space:]]+DELETE|git[[:space:]]+push[^[:cntrl:]]+--delete' "$policy" "$sdk" "$distribution"; then
  echo "::error::Automation branch cleanup must never delete historical refs." >&2
  exit 1
fi

# 10. An exact-head lease rejects a branch changed after verification.
remote="$scratch/remote.git"
seed="$scratch/seed"
racer="$scratch/racer"
git init --quiet --bare "$remote"
git clone --quiet "$remote" "$seed"
git -C "$seed" config user.name fixture
git -C "$seed" config user.email fixture@example.invalid
echo base > "$seed/file.txt"
git -C "$seed" add file.txt
git -C "$seed" commit --quiet -m base
git -C "$seed" push --quiet origin HEAD:main
git -C "$seed" checkout --quiet -b "$branch"
echo owned >> "$seed/file.txt"
git -C "$seed" commit --quiet -am owned
git -C "$seed" push --quiet origin "HEAD:refs/heads/$branch"
captured_sha="$(git ls-remote "$remote" "refs/heads/$branch" | awk '{print $1}')"
git clone --quiet --branch "$branch" "$remote" "$racer"
git -C "$racer" config user.name racer
git -C "$racer" config user.email racer@example.invalid
echo race >> "$racer/file.txt"
git -C "$racer" commit --quiet -am race
git -C "$racer" push --quiet origin "HEAD:refs/heads/$branch"
echo candidate >> "$seed/file.txt"
git -C "$seed" commit --quiet -am candidate
if git -C "$seed" push --quiet --force-with-lease="refs/heads/$branch:$captured_sha" \
  origin "HEAD:refs/heads/$branch" 2>/dev/null; then
  echo "::error::A stale exact-head lease overwrote a changed branch." >&2
  exit 1
fi

# 12. Dry-run exits before ownership lookup, git setup, pushes or PR mutation.
dry_run_line="$(grep -n 'if \[\[ "$DRY_RUN" == "true" \]\]' "$sdk" | tail -n 1 | cut -d: -f1)"
selection_line="$(grep -n 'select_automation_branch' "$sdk" | tail -n 1 | cut -d: -f1)"
[[ "$dry_run_line" -lt "$selection_line" ]]
dry_run_line="$(grep -n 'if \[\[ "$DRY_RUN" == "true" \]\]' "$distribution" | tail -n 1 | cut -d: -f1)"
selection_line="$(grep -n 'select_automation_branch' "$distribution" | tail -n 1 | cut -d: -f1)"
[[ "$dry_run_line" -lt "$selection_line" ]]

# Mutation scope and lease contracts remain narrow.
grep -Fq 'git -C "$sdk_worktree" add -- "$GLOBAL_JSON_PATH"' "$sdk"
grep -Fq 'git -C "$worktree" add -- "${changed_targets[@]}"' "$distribution"
grep -Fq -- '--force-with-lease="refs/heads/$active_branch:$branch_parent_sha"' "$sdk"
grep -Fq -- '--force-with-lease="refs/heads/$active_branch:$AUTOMATION_BRANCH_SHA"' "$distribution"
if grep -Eq 'git[[:space:]].*push[[:space:]].*--force([[:space:]]|$)' "$sdk" "$distribution"; then
  echo "::error::Unprotected force push detected." >&2
  exit 1
fi

echo "Automation ownership, orphan recovery, idempotency, race and dry-run regressions passed."
