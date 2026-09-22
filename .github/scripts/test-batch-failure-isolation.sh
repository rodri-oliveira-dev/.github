#!/usr/bin/env bash
set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$root/.github/scripts/batch-retry.sh"

sdk="$root/.github/workflows/dotnet-sdk-sync.yml"
distribution="$root/.github/workflows/distribute-agent-skills.yml"
upstream="$root/.github/workflows/sync-agent-skills.yml"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
fixture_output="$scratch/response"
attempts="$scratch/attempts"
fixture_case=""

fake_curl() {
  printf 'attempt\n' >> "$attempts"
  local attempt
  attempt="$(wc -l < "$attempts")"
  case "$fixture_case" in
    transient-503)
      if (( attempt < 3 )); then
        printf '%s' "503"
      else
        printf '%s' "200"
      fi
      ;;
    transient-network)
      if (( attempt < 2 )); then
        return 28
      fi
      printf '%s' "200"
      ;;
    deterministic-404)
      printf '%s' "404"
      ;;
    deterministic-422)
      printf '%s' "422"
      ;;
    persistent-503)
      printf '%s' "503"
      ;;
    error)
      return 22
      ;;
    success)
      printf '%s' "200"
      ;;
    *)
      return 1
      ;;
  esac
}

assert_reads() {
  local mode="$1" expected_status="$2" expected_count="$3"
  : > "$attempts"
  fixture_case="$mode"
  local status
  status="$(batch_retry_http_get "$fixture_output" fake_curl --get)"
  [[ "$status" == "$expected_status" ]]
  [[ "$(wc -l < "$attempts")" -eq "$expected_count" ]]
}

# Retry only transient read-only API failure classes. 4xx is deterministic
# (other than 429) and must not be retried.
assert_reads transient-503 200 3
assert_reads transient-network 200 2
assert_reads persistent-503 503 3
assert_reads deterministic-404 404 1
assert_reads deterministic-422 422 1

: > "$attempts"
fixture_case="success"
if batch_retry_http_get "$fixture_output" fake_curl --get --request POST >/dev/null 2>&1; then
  echo "::error::Non-idempotent HTTP mutation was incorrectly accepted for retries."
  exit 1
fi
[[ ! -s "$attempts" ]]

# The workflows must source the production retry helper and preserve per-repo
# mutation/transport guards. API errors, clone errors, push errors, and PR
# creation errors must all be captured before the next loop iteration.
grep -Fq 'source "$GITHUB_WORKSPACE/.github/scripts/batch-retry.sh"' "$sdk"
grep -Fq 'source "$GOVERNANCE_ROOT/.github/scripts/batch-retry.sh"' "$distribution"
grep -Fq 'batch_retry_http_get "$file_response_file" curl' "$sdk"
grep -Fq 'batch_retry_http_get "$exact_source_response_file" curl' "$sdk"
grep -Fq 'batch_retry_http_get "$output" curl' "$distribution"
grep -Fq 'if ! http_status="$(fetch_consumer_file ' "$distribution"
grep -Fq 'if ! git clone --quiet --branch "$default_branch"' "$distribution"
grep -Fq 'if ! git -C "$worktree" commit -m "$PR_TITLE"' "$distribution"
grep -Fq 'if ! git -C "$worktree" push --quiet' "$distribution"
grep -Fq 'if ! pr_url="$(' "$distribution"
grep -Fq 'if ! git -C "$sdk_worktree" fetch --quiet' "$sdk"
grep -Fq 'if ! git -C "$sdk_worktree" push --quiet' "$sdk"
grep -Fq 'if ! pr_url="$(' "$sdk"
grep -Fq 'if ! reconcile_existing_pr_metadata "$repo"' "$sdk"
grep -Fq 'repository_errors=$((repository_errors + 1))' "$sdk"
grep -Fq 'repository_errors=$((repository_errors + 1))' "$distribution"
grep -Fq 'done < "$repositories_file"' "$sdk"
grep -Fq 'done < "$repositories_file"' "$distribution"
grep -Fq 'if [[ "$repository_errors" -gt 0' "$sdk"
grep -Fq 'if [[ "$repository_errors" -gt 0 ]]; then' "$distribution"

# Deterministic per-repository harness with injected API, clone, push, and PR
# errors followed by a successful consumer. It exercises the same fail/continue
# contract without writing to real repositories.
fake_git() {
  local repo="$1" operation="$2"
  [[ "$repo:$operation" != "clone-error:clone" &&
     "$repo:$operation" != "push-error:push" ]]
}

fake_gh_pr_create() {
  local repo="$1"
  [[ "$repo" != "pr-error" ]]
}

errors=0
successes=0
declare -a outcomes=()
for repo in api-error clone-error push-error pr-error successor; do
  fixture_case="success"
  if [[ "$repo" == "api-error" ]]; then
    fixture_case="error"
  fi
  : > "$attempts"
  if ! batch_retry_http_get "$fixture_output" fake_curl --get > "$scratch/http-status"; then
    outcomes+=("$repo:error-api")
    errors=$((errors + 1))
    continue
  fi
  if ! fake_git "$repo" clone; then
    outcomes+=("$repo:error-clone")
    errors=$((errors + 1))
    continue
  fi
  if ! fake_git "$repo" push; then
    outcomes+=("$repo:error-push")
    errors=$((errors + 1))
    continue
  fi
  if ! fake_gh_pr_create "$repo"; then
    outcomes+=("$repo:error-pr")
    errors=$((errors + 1))
    continue
  fi
  outcomes+=("$repo:success")
  successes=$((successes + 1))
done

[[ "$errors" -eq 4 && "$successes" -eq 1 ]]
[[ "${outcomes[*]}" == "api-error:error-api clone-error:error-clone push-error:error-push pr-error:error-pr successor:success" ]]

# This is a single-target upstream synchronization, not a consumer batch.
# A failure there correctly fails the job rather than suppressing the error.
grep -Fq 'TARGET_REPO:' "$upstream"

echo "Batch read retry and per-repository failure isolation regression harness passed."
