#!/usr/bin/env bash
# Offline proof that releases fail closed without enforced and actual reviews.
set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
guard="$root/.github/scripts/validate-reusable-workflow-release-approval.sh"
bash -n "$guard"

fixtures="$(mktemp -d)"
trap 'rm -rf -- "$fixtures"' EXIT
mkdir -p "$fixtures/bin"

export GITHUB_REPOSITORY="rodri-oliveira-dev/.github"
export GITHUB_REF="refs/heads/main"
export RELEASE_TARGET_SHA="3333333333333333333333333333333333333333"
export GH_TOKEN="offline-fixture-token"
export MOCK_HEAD_SHA="4444444444444444444444444444444444444444"
export MOCK_AUTHOR="release-author"
export MOCK_REVIEWER="independent-reviewer"
export MOCK_APPROVAL_SHA="$MOCK_HEAD_SHA"
export MOCK_APPROVED=true
export MOCK_RULESET="$fixtures/ruleset.json"
export MOCK_PRS="$fixtures/pulls.json"
export MOCK_CALLS="$fixtures/calls"

cat > "$MOCK_RULESET" <<'JSON'
{"name":"main-hardened","source":"rodri-oliveira-dev/.github","target":"branch","enforcement":"active","conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},"bypass_actors":[],"current_user_can_bypass":"never","rules":[{"type":"pull_request","parameters":{"required_approving_review_count":1}}]}
JSON
cat > "$MOCK_PRS" <<'JSON'
[{"number":59,"merged_at":"2026-09-23T12:00:00Z","base":{"ref":"main"}}]
JSON

cat > "$fixtures/bin/gh" <<'GH'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$MOCK_CALLS"
if [[ "${1:-}" == api && "${2:-}" == "repos/$GITHUB_REPOSITORY/rulesets?per_page=100" ]]; then
  printf '%s\n' '[{"id":23877696,"name":"main-hardened","target":"branch","enforcement":"active"}]'
elif [[ "${1:-}" == api && "${2:-}" == "repos/$GITHUB_REPOSITORY/rulesets/23877696" ]]; then
  [[ "${MOCK_RULESET_API_ERROR:-false}" != true ]] || exit 1
  cat "$MOCK_RULESET"
elif [[ "${1:-}" == api && "${2:-}" == "repos/$GITHUB_REPOSITORY/commits/$RELEASE_TARGET_SHA/pulls?per_page=100" ]]; then
  cat "$MOCK_PRS"
elif [[ "${1:-}" == api && "${2:-}" == "repos/$GITHUB_REPOSITORY/pulls/59" ]]; then
  printf '%s|%s\n' "$MOCK_HEAD_SHA" "$MOCK_AUTHOR"
elif [[ "${1:-}" == api && "${2:-}" == --paginate && "${3:-}" == "repos/$GITHUB_REPOSITORY/pulls/59/reviews?per_page=100" ]]; then
  if [[ "$MOCK_APPROVED" == true ]]; then
    printf '%s|%s\n' "$MOCK_APPROVAL_SHA" "$MOCK_REVIEWER"
  fi
else
  printf 'Unexpected mock GitHub call: %s\n' "$*" >&2
  exit 2
fi
GH
chmod +x "$fixtures/bin/gh"
export PATH="$fixtures/bin:$PATH"

run_guard() {
  : > "$MOCK_CALLS"
  bash "$guard" > "$fixtures/stdout" 2> "$fixtures/stderr"
}

reject_guard() {
  local description="$1" expected="$2"
  if run_guard; then
    echo "::error::$description unexpectedly allowed publication." >&2
    exit 1
  fi
  grep -Fq "$expected" "$fixtures/stderr" || {
    cat "$fixtures/stderr" >&2
    echo "::error::$description failed with an unexpected diagnostic." >&2
    exit 1
  }
  if grep -Eq -- '(^| )--method (POST|PATCH|PUT|DELETE)( |$)' "$MOCK_CALLS"; then
    echo "::error::Approval validation mutated GitHub state." >&2
    exit 1
  fi
}

run_guard
grep -Fq 'approved in PR #59' "$fixtures/stdout"

cp "$MOCK_RULESET" "$fixtures/strong.json"
# A GITHUB_TOKEN without ruleset-write access sees no bypass_actors field.
# The missing list is not an empty list: the release principal must still
# explicitly report that it cannot bypass the active ruleset.
jq 'del(.bypass_actors)' "$fixtures/strong.json" > "$MOCK_RULESET"
run_guard
grep -Fq 'approved in PR #59' "$fixtures/stdout"

jq 'del(.bypass_actors, .current_user_can_bypass)' "$fixtures/strong.json" > "$MOCK_RULESET"
reject_guard "omitted bypass list without proof of token restrictions" "the release token must not bypass it"
jq 'del(.bypass_actors) | .current_user_can_bypass = "always"' "$fixtures/strong.json" > "$MOCK_RULESET"
reject_guard "hidden bypass list with privileged release token" "the release token must not bypass it"
jq '.current_user_can_bypass = "always"' "$fixtures/strong.json" > "$MOCK_RULESET"
reject_guard "privileged release token with visible empty bypass list" "the release token must not bypass it"
cp "$fixtures/strong.json" "$MOCK_RULESET"

jq '.rules[0].parameters.required_approving_review_count = 0' "$fixtures/strong.json" > "$MOCK_RULESET"
reject_guard "zero required approving reviews" "must require an approving review"
cp "$fixtures/strong.json" "$MOCK_RULESET"

jq '.bypass_actors = [{"actor_id":123,"actor_type":"Team","bypass_mode":"always"}]' "$fixtures/strong.json" > "$MOCK_RULESET"
reject_guard "ruleset with visible bypass actors" "any visible bypass list must be empty"
cp "$fixtures/strong.json" "$MOCK_RULESET"

MOCK_RULESET_API_ERROR=true reject_guard "ruleset API failure" "Cannot verify the main-hardened ruleset"
MOCK_APPROVED=false reject_guard "unreviewed VERSION change" "has no non-author approval"
MOCK_APPROVAL_SHA="5555555555555555555555555555555555555555" reject_guard "approval on stale head" "has no non-author approval"
MOCK_REVIEWER="$MOCK_AUTHOR" reject_guard "self approval" "has no non-author approval"

printf '%s\n' 'Reviewed main protection, PR provenance, exact-head approval and fail-closed fixtures passed.'
