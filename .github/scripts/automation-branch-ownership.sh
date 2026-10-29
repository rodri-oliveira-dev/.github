#!/usr/bin/env bash
# shellcheck disable=SC2034 # Outputs are consumed by scripts that source this policy.

# Shared fail-closed provenance and collision recovery for reserved automation
# branches. This file is sourced by privileged workflows; keep it side-effect
# free. All API calls in this policy are read-only.

AUTOMATION_BRANCH_STATE=""
AUTOMATION_BRANCH_SHA=""
AUTOMATION_BRANCH_NAME=""
AUTOMATION_PR_NUMBER=""
AUTOMATION_PR_URL=""
AUTOMATION_OWNERSHIP_ERROR=""
AUTOMATION_RECOVERY_USED="false"
AUTOMATION_RECOVERY_REASON=""

_automation_marker_id() {
  local marker="$1"
  sed -n 's/^<!--[[:space:]]*automation-branch-owner:[[:space:]]*\([^[:space:]]\+\)[[:space:]]*-->$/\1/p' <<< "$marker"
}

_automation_recovery_branch() {
  local branch_name="$1" marker_id="$2" slug
  slug="$(tr '[:upper:]' '[:lower:]' <<< "$marker_id" | sed 's#[^a-z0-9._-]#-#g; s#-*$##')"
  printf '%s-%s-managed\n' "$branch_name" "$slug"
}

_automation_files_are_managed() {
  local repo="$1" pr_number="$2" allowed_paths="$3" files_json file_count
  [[ -n "$allowed_paths" ]] || return 1
  if ! files_json="$(gh api --method GET --paginate "repos/$repo/pulls/$pr_number/files?per_page=100")"; then
    AUTOMATION_OWNERSHIP_ERROR="unable to inspect changed files for legacy Pull Request #$pr_number"
    return 2
  fi
  file_count="$(jq -s '[.[][]?] | length' <<< "$files_json")"
  [[ "$file_count" =~ ^[0-9]+$ && "$file_count" -gt 0 ]] || return 1
  jq -es --arg allowed "$allowed_paths" '
    ($allowed | split("\n") | map(select(length > 0))) as $paths
    | [ .[][]? | .filename ] as $files
    | ($files | length) > 0
      and all($files[]; . as $file | any($paths[]; . == $file))
  ' <<< "$files_json" >/dev/null
}

_automation_legacy_title_matches() {
  local title="$1" expected_title="$2" marker_id="$3"
  if [[ -n "$expected_title" ]]; then
    [[ "$title" == "$expected_title" ]]
    return
  fi
  case "$marker_id" in
    dotnet-sdk-sync/*) [[ "$title" == "chore: update .NET SDK from "*" to "* ]] ;;
    *) return 1 ;;
  esac
}

verify_automation_branch_ownership() {
  local repo="${1:-}" branch_name="${2:-}" base_branch="${3:-}"
  local ownership_marker="${4:-}" expected_title="${5:-}" allowed_paths="${6:-}"
  local owner ref_name refs_json remote_count remote_sha="" prs_json pr_count open_count
  local pr_json pr_number pr_url pr_title pr_body pr_head_sha pr_head_ref pr_head_repo
  local pr_base_ref pr_author_login pr_author_type marker_id merged_at state legacy_files_result

  AUTOMATION_BRANCH_STATE=""
  AUTOMATION_BRANCH_SHA=""
  AUTOMATION_BRANCH_NAME="$branch_name"
  AUTOMATION_PR_NUMBER=""
  AUTOMATION_PR_URL=""
  AUTOMATION_OWNERSHIP_ERROR=""
  AUTOMATION_RECOVERY_USED="false"
  AUTOMATION_RECOVERY_REASON=""

  if [[ -z "$repo" || -z "$branch_name" || -z "$base_branch" || -z "$ownership_marker" ]]; then
    AUTOMATION_OWNERSHIP_ERROR="repository, reserved branch, base branch and ownership marker are required"
    return 1
  fi
  if [[ "$branch_name" == "$base_branch" ]]; then
    AUTOMATION_OWNERSHIP_ERROR="reserved automation branch '$branch_name' must never equal the default/base branch"
    return 1
  fi
  marker_id="$(_automation_marker_id "$ownership_marker")"
  if [[ -z "$marker_id" ]]; then
    AUTOMATION_OWNERSHIP_ERROR="ownership marker has an invalid format"
    return 1
  fi

  owner="${repo%%/*}"
  ref_name="refs/heads/$branch_name"
  if ! refs_json="$(gh api --method GET "repos/$repo/git/matching-refs/heads/$branch_name")"; then
    AUTOMATION_OWNERSHIP_ERROR="unable to read remote branch state for $repo:$branch_name"
    return 1
  fi
  remote_count="$(jq -r --arg ref "$ref_name" '[.[] | select(.ref == $ref)] | length' <<< "$refs_json")"
  if [[ ! "$remote_count" =~ ^[0-9]+$ ]] || [[ "$remote_count" -gt 1 ]]; then
    AUTOMATION_BRANCH_STATE="conflict"
    AUTOMATION_OWNERSHIP_ERROR="unexpected or conflicting remote ref state for $repo:$branch_name"
    return 0
  fi
  if [[ "$remote_count" -eq 0 ]]; then
    AUTOMATION_BRANCH_STATE="absent"
    return 0
  fi

  remote_sha="$(jq -r --arg ref "$ref_name" '.[] | select(.ref == $ref) | .object.sha // empty' <<< "$refs_json")"
  if [[ ! "$remote_sha" =~ ^[0-9a-fA-F]{40}$ ]]; then
    AUTOMATION_BRANCH_STATE="conflict"
    AUTOMATION_OWNERSHIP_ERROR="remote branch $repo:$branch_name did not resolve to one commit SHA"
    return 0
  fi
  AUTOMATION_BRANCH_SHA="$remote_sha"

  if ! prs_json="$(gh api --method GET --paginate "repos/$repo/pulls" \
    -f state=all -f head="$owner:$branch_name" -f base="$base_branch" -f per_page=100)"; then
    AUTOMATION_OWNERSHIP_ERROR="unable to correlate Pull Request history for $repo:$branch_name"
    return 1
  fi
  pr_count="$(jq -s '[.[][]?] | length' <<< "$prs_json")"
  open_count="$(jq -s '[.[][]? | select(.state == "open")] | length' <<< "$prs_json")"
  if [[ ! "$pr_count" =~ ^[0-9]+$ || ! "$open_count" =~ ^[0-9]+$ ]]; then
    AUTOMATION_OWNERSHIP_ERROR="unexpected Pull Request lookup result for $repo:$branch_name"
    return 1
  fi

  if [[ "$open_count" -gt 1 ]]; then
    AUTOMATION_BRANCH_STATE="conflict_open"
    AUTOMATION_OWNERSHIP_ERROR="multiple open Pull Requests reference $repo:$branch_name"
    return 0
  fi
  if [[ "$open_count" -eq 1 ]]; then
    pr_json="$(jq -sc '[.[][]? | select(.state == "open")][0]' <<< "$prs_json")"
  elif [[ "$pr_count" -eq 0 ]]; then
    AUTOMATION_BRANCH_STATE="unproven"
    AUTOMATION_OWNERSHIP_ERROR="reserved branch $repo:$branch_name has no Pull Request history; ownership is unproven"
    return 0
  elif [[ "$pr_count" -gt 1 ]]; then
    AUTOMATION_BRANCH_STATE="historical_conflict"
    AUTOMATION_OWNERSHIP_ERROR="multiple historical Pull Requests reference $repo:$branch_name without one open owner"
    return 0
  else
    pr_json="$(jq -sc '[.[][]?][0]' <<< "$prs_json")"
  fi

  pr_number="$(jq -r '.number // empty' <<< "$pr_json")"
  pr_url="$(jq -r '.html_url // empty' <<< "$pr_json")"
  pr_title="$(jq -r '.title // empty' <<< "$pr_json")"
  pr_body="$(jq -r '.body // ""' <<< "$pr_json")"
  pr_head_sha="$(jq -r '.head.sha // empty' <<< "$pr_json")"
  pr_head_ref="$(jq -r '.head.ref // empty' <<< "$pr_json")"
  pr_head_repo="$(jq -r '.head.repo.full_name // empty' <<< "$pr_json")"
  pr_base_ref="$(jq -r '.base.ref // empty' <<< "$pr_json")"
  pr_author_login="$(jq -r '.user.login // empty' <<< "$pr_json")"
  pr_author_type="$(jq -r '.user.type // empty' <<< "$pr_json")"
  merged_at="$(jq -r '.merged_at // empty' <<< "$pr_json")"
  state="$(jq -r '.state // empty' <<< "$pr_json")"

  if [[ "$pr_head_repo" != "$repo" || "$pr_head_ref" != "$branch_name" || "$pr_base_ref" != "$base_branch" ]]; then
    AUTOMATION_BRANCH_STATE="conflict"
    AUTOMATION_OWNERSHIP_ERROR="Pull Request provenance conflicts with repository/head/base for $repo:$branch_name"
    return 0
  fi
  if [[ "$pr_head_sha" != "$remote_sha" ]]; then
    if [[ "$state" == "open" ]]; then
      AUTOMATION_BRANCH_STATE="modified"
    else
      AUTOMATION_BRANCH_STATE="historical_modified"
    fi
    AUTOMATION_OWNERSHIP_ERROR="branch $repo:$branch_name changed after Pull Request #$pr_number recorded its head SHA"
    return 0
  fi

  AUTOMATION_PR_NUMBER="$pr_number"
  AUTOMATION_PR_URL="$pr_url"
  if [[ "$state" == "open" ]]; then
    if [[ "$pr_author_type" != "Bot" || "$pr_author_login" != *'[bot]' ]]; then
      AUTOMATION_BRANCH_STATE="unproven_open"
      AUTOMATION_OWNERSHIP_ERROR="Pull Request #$pr_number was not authored by a GitHub App bot identity"
      return 0
    fi
    if [[ -n "$expected_title" && "$pr_title" != "$expected_title" ]]; then
      AUTOMATION_BRANCH_STATE="unproven_open"
      AUTOMATION_OWNERSHIP_ERROR="Pull Request #$pr_number has an unexpected title; ownership is unproven"
      return 0
    fi
    if grep -Fq -- "$ownership_marker" <<< "$pr_body"; then
      if _automation_files_are_managed "$repo" "$pr_number" "$allowed_paths"; then
        AUTOMATION_BRANCH_STATE="owned"
        return 0
      else
        legacy_files_result=$?
        [[ "$legacy_files_result" -ne 2 ]] || return 1
        AUTOMATION_BRANCH_STATE="modified"
        AUTOMATION_OWNERSHIP_ERROR="Pull Request #$pr_number changes files outside the automation's managed scope"
        return 0
      fi
    fi
    if _automation_legacy_title_matches "$pr_title" "$expected_title" "$marker_id"; then
      if _automation_files_are_managed "$repo" "$pr_number" "$allowed_paths"; then
        AUTOMATION_BRANCH_STATE="owned_legacy"
        return 0
      else
        legacy_files_result=$?
        [[ "$legacy_files_result" -ne 2 ]] || return 1
      fi
    fi
    AUTOMATION_BRANCH_STATE="unproven_open"
    AUTOMATION_OWNERSHIP_ERROR="Pull Request #$pr_number lacks the marker and strict legacy ownership evidence"
    return 0
  fi

  if [[ -n "$merged_at" ]]; then
    AUTOMATION_BRANCH_STATE="historical_merged"
    AUTOMATION_OWNERSHIP_ERROR="reserved branch remains after merged Pull Request #$pr_number"
  else
    AUTOMATION_BRANCH_STATE="historical_closed"
    AUTOMATION_OWNERSHIP_ERROR="reserved branch remains after Pull Request #$pr_number was closed without merge"
  fi
  return 0
}

select_automation_branch() {
  local repo="${1:-}" preferred_branch="${2:-}" base_branch="${3:-}"
  local ownership_marker="${4:-}" expected_title="${5:-}" allowed_paths="${6:-}"
  local recovery_branch primary_state primary_sha primary_pr_number primary_pr_url primary_error
  local recovery_state recovery_sha recovery_pr_number recovery_pr_url recovery_error
  local primary_owned="false" recovery_owned="false"
  local primary_recoverable="false" recovery_recoverable="false"

  if ! verify_automation_branch_ownership "$repo" "$preferred_branch" "$base_branch" \
    "$ownership_marker" "$expected_title" "$allowed_paths"; then
    return 1
  fi
  primary_state="$AUTOMATION_BRANCH_STATE"
  primary_sha="$AUTOMATION_BRANCH_SHA"
  primary_pr_number="$AUTOMATION_PR_NUMBER"
  primary_pr_url="$AUTOMATION_PR_URL"
  primary_error="$AUTOMATION_OWNERSHIP_ERROR"
  recovery_branch="$(_automation_recovery_branch "$preferred_branch" "$(_automation_marker_id "$ownership_marker")")"
  if [[ "$recovery_branch" == "$preferred_branch" || "$recovery_branch" == "$base_branch" ]]; then
    AUTOMATION_OWNERSHIP_ERROR="unable to derive a safe recovery branch for $repo:$preferred_branch"
    return 1
  fi
  if ! verify_automation_branch_ownership "$repo" "$recovery_branch" "$base_branch" \
    "$ownership_marker" "$expected_title" "$allowed_paths"; then
    return 1
  fi
  recovery_state="$AUTOMATION_BRANCH_STATE"
  recovery_sha="$AUTOMATION_BRANCH_SHA"
  recovery_pr_number="$AUTOMATION_PR_NUMBER"
  recovery_pr_url="$AUTOMATION_PR_URL"
  recovery_error="$AUTOMATION_OWNERSHIP_ERROR"

  if [[ "$primary_state" == "owned" || "$primary_state" == "owned_legacy" ]]; then
    primary_owned="true"
  fi
  if [[ "$recovery_state" == "owned" || "$recovery_state" == "owned_legacy" ]]; then
    recovery_owned="true"
  fi
  case "$primary_state" in
    absent|historical_merged|historical_closed|historical_modified|historical_conflict|unproven) primary_recoverable="true" ;;
  esac
  case "$recovery_state" in
    absent|historical_merged|historical_closed|historical_modified|historical_conflict|unproven) recovery_recoverable="true" ;;
  esac
  if [[ "$primary_owned" == "true" && "$recovery_owned" == "true" ]]; then
    AUTOMATION_BRANCH_STATE="conflict"
    AUTOMATION_BRANCH_NAME=""
    AUTOMATION_BRANCH_SHA=""
    AUTOMATION_PR_NUMBER=""
    AUTOMATION_PR_URL=""
    AUTOMATION_OWNERSHIP_ERROR="both preferred and recovery branches have open automation Pull Requests"
    return 1
  fi

  if [[ "$primary_owned" != "true" && "$primary_recoverable" != "true" ]]; then
    AUTOMATION_BRANCH_STATE="$primary_state"
    AUTOMATION_BRANCH_NAME=""
    AUTOMATION_BRANCH_SHA=""
    AUTOMATION_PR_NUMBER=""
    AUTOMATION_PR_URL=""
    AUTOMATION_OWNERSHIP_ERROR="preferred branch has an unsafe open or modified state: $primary_error"
    return 1
  fi
  if [[ "$recovery_owned" != "true" && "$recovery_recoverable" != "true" ]]; then
    AUTOMATION_BRANCH_STATE="$recovery_state"
    AUTOMATION_BRANCH_NAME=""
    AUTOMATION_BRANCH_SHA=""
    AUTOMATION_PR_NUMBER=""
    AUTOMATION_PR_URL=""
    AUTOMATION_OWNERSHIP_ERROR="recovery branch has an unsafe open or modified state: $recovery_error"
    return 1
  fi

  if [[ "$primary_owned" == "true" || ( "$primary_state" == "absent" && "$recovery_owned" != "true" ) ]]; then
    AUTOMATION_BRANCH_STATE="$primary_state"
    AUTOMATION_BRANCH_NAME="$preferred_branch"
    AUTOMATION_BRANCH_SHA="$primary_sha"
    AUTOMATION_PR_NUMBER="$primary_pr_number"
    AUTOMATION_PR_URL="$primary_pr_url"
    AUTOMATION_OWNERSHIP_ERROR="$primary_error"
    AUTOMATION_RECOVERY_USED="false"
    AUTOMATION_RECOVERY_REASON=""
    return 0
  fi

  if [[ "$recovery_owned" == "true" || "$recovery_state" == "absent" ]]; then
    AUTOMATION_BRANCH_STATE="$recovery_state"
    AUTOMATION_BRANCH_NAME="$recovery_branch"
    AUTOMATION_BRANCH_SHA="$recovery_sha"
    AUTOMATION_PR_NUMBER="$recovery_pr_number"
    AUTOMATION_PR_URL="$recovery_pr_url"
    AUTOMATION_OWNERSHIP_ERROR="$recovery_error"
    AUTOMATION_RECOVERY_USED="true"
    AUTOMATION_RECOVERY_REASON="$primary_state: $primary_error"
    return 0
  fi

  AUTOMATION_BRANCH_STATE="conflict"
  AUTOMATION_BRANCH_NAME=""
  AUTOMATION_BRANCH_SHA=""
  AUTOMATION_PR_NUMBER=""
  AUTOMATION_PR_URL=""
  AUTOMATION_OWNERSHIP_ERROR="preferred branch is $primary_state ($primary_error); recovery branch '$recovery_branch' is $recovery_state ($recovery_error)"
  return 1
}
