#!/usr/bin/env bash
# Fail closed unless the VERSION change was reviewed and main protection
# currently requires approval without bypass. No Git refs are mutated here.
set -Eeuo pipefail

die() {
  printf '::error title=Reusable workflow approval::%s\n' "$*" >&2
  exit 1
}

repo="${GITHUB_REPOSITORY:-}"
target="${RELEASE_TARGET_SHA:-}"
[[ "$repo" == "rodri-oliveira-dev/.github" ]] || die "Unexpected repository."
[[ "${GITHUB_REF:-}" == "refs/heads/main" ]] || die "Release approval is only valid on main."
[[ "$target" =~ ^[0-9a-f]{40}$ ]] || die "Expected a reviewed 40-character release commit."
[[ -n "${GH_TOKEN:-}" ]] || die "GH_TOKEN is required to verify review and branch protection."
command -v gh >/dev/null 2>&1 || die "gh CLI is required."
command -v jq >/dev/null 2>&1 || die "jq is required."

rulesets="$(gh api "repos/$repo/rulesets?per_page=100")" ||
  die "Cannot read active repository rulesets."
ruleset_id="$(jq -er '
  [.[] | select(.name == "main-hardened" and .target == "branch" and .enforcement == "active")] |
  if length == 1 then .[0].id else error("Expected exactly one active main-hardened branch ruleset") end
' <<< "$rulesets")" || die "Active main-hardened ruleset is unavailable or ambiguous."
[[ "$ruleset_id" =~ ^[1-9][0-9]*$ ]] || die "Invalid main-hardened ruleset identifier."

ruleset="$(gh api "repos/$repo/rulesets/$ruleset_id")" ||
  die "Cannot verify the main-hardened ruleset."
jq -e --arg repo "$repo" '
  .name == "main-hardened" and .source == $repo and .target == "branch" and
  .enforcement == "active" and
  (.conditions.ref_name.include | index("~DEFAULT_BRANCH") != null) and
  (.conditions.ref_name.exclude | length == 0) and
  # The GITHUB_TOKEN cannot see the full bypass_actors list unless it has
  # ruleset-write access. Never interpret an omitted field as an empty list:
  # require the release principal itself to have no bypass permission, and
  # reject any nonempty bypass list when GitHub does return it.
  (.current_user_can_bypass == "never") and
  (if has("bypass_actors") then
    (.bypass_actors | type == "array" and length == 0)
   else true end) and
  ([.rules[] | select(.type == "pull_request" and
    (.parameters.required_approving_review_count >= 1))] | length == 1)
' <<< "$ruleset" >/dev/null ||
  die "Release blocked: main-hardened must require an approving review, the release token must not bypass it, and any visible bypass list must be empty. Update the active ruleset before publication."

associated="$(gh api "repos/$repo/commits/$target/pulls?per_page=100")" ||
  die "Cannot trace the release target to its merged Pull Request."
pr_number="$(jq -er '
  [.[] | select(.merged_at != null and .base.ref == "main")] |
  if length == 1 then .[0].number else error("Expected one merged main Pull Request for VERSION") end
' <<< "$associated")" || die "Release target has no unique merged Pull Request provenance."
[[ "$pr_number" =~ ^[1-9][0-9]*$ ]] || die "Invalid release Pull Request number."

pr_details="$(gh api "repos/$repo/pulls/$pr_number" --jq '[.head.sha, .user.login] | join("|")')" ||
  die "Cannot inspect the merged release Pull Request."
IFS='|' read -r head_sha author <<< "$pr_details"
[[ "$head_sha" =~ ^[0-9a-f]{40}$ && -n "$author" ]] ||
  die "Merged release Pull Request is missing head SHA or author."

review_rows="$(gh api --paginate "repos/$repo/pulls/$pr_number/reviews?per_page=100" \
  --jq '.[] | select(.state == "APPROVED") | [.commit_id, .user.login] | join("|")')" ||
  die "Cannot enumerate release Pull Request approvals."
approved=false
while IFS='|' read -r review_sha reviewer; do
  if [[ "$review_sha" == "$head_sha" && -n "$reviewer" && "$reviewer" != "$author" ]]; then
    approved=true
    break
  fi
done <<< "$review_rows"
[[ "$approved" == true ]] ||
  die "Release blocked: PR #$pr_number has no non-author approval of its final head commit."

printf 'Release target %s was approved in PR #%s and main protection requires review.\n' \
  "$target" "$pr_number"
