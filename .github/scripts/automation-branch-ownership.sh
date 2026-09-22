#!/usr/bin/env bash

# Shared fail-closed provenance check for reserved automation branches.
# This file is sourced by privileged workflows; keep it side-effect free.

AUTOMATION_BRANCH_STATE=""
AUTOMATION_BRANCH_SHA=""
AUTOMATION_PR_NUMBER=""
AUTOMATION_PR_URL=""
AUTOMATION_OWNERSHIP_ERROR=""

verify_automation_branch_ownership() {
  local repo="${1:-}"
  local branch_name="${2:-}"
  local base_branch="${3:-}"
  local ownership_marker="${4:-}"
  local expected_title="${5:-}"
  local owner
  local ref_name
  local refs_json
  local remote_count
  local remote_sha=""
  local prs_json
  local pr_count
  local pr_number
  local pr_url
  local pr_title
  local pr_body
  local pr_head_sha
  local pr_head_ref
  local pr_head_repo
  local pr_base_ref

  AUTOMATION_BRANCH_STATE=""
  AUTOMATION_BRANCH_SHA=""
  AUTOMATION_PR_NUMBER=""
  AUTOMATION_PR_URL=""
  AUTOMATION_OWNERSHIP_ERROR=""

  if [[ -z "$repo" || -z "$branch_name" || -z "$base_branch" || -z "$ownership_marker" ]]; then
    AUTOMATION_OWNERSHIP_ERROR="repository, reserved branch, base branch and ownership marker are required"
    return 1
  fi

  if [[ "$branch_name" == "$base_branch" ]]; then
    AUTOMATION_OWNERSHIP_ERROR="reserved automation branch '$branch_name' must never equal the default/base branch"
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
    AUTOMATION_OWNERSHIP_ERROR="unexpected remote ref state for $repo:$branch_name"
    return 1
  fi

  if [[ "$remote_count" -eq 1 ]]; then
    remote_sha="$(jq -r --arg ref "$ref_name" '.[] | select(.ref == $ref) | .object.sha // empty' <<< "$refs_json")"
    if [[ ! "$remote_sha" =~ ^[0-9a-fA-F]{40}$ ]]; then
      AUTOMATION_OWNERSHIP_ERROR="remote branch $repo:$branch_name did not resolve to a commit SHA"
      return 1
    fi
  fi

  if ! prs_json="$(
    gh api --method GET "repos/$repo/pulls" \
      -f state=open \
      -f head="$owner:$branch_name" \
      -f base="$base_branch" \
      -f per_page=100
  )"; then
    AUTOMATION_OWNERSHIP_ERROR="unable to correlate open Pull Requests for $repo:$branch_name"
    return 1
  fi

  pr_count="$(jq -r 'length' <<< "$prs_json")"
  if [[ ! "$pr_count" =~ ^[0-9]+$ ]]; then
    AUTOMATION_OWNERSHIP_ERROR="unexpected Pull Request lookup result for $repo:$branch_name"
    return 1
  fi

  if [[ "$remote_count" -eq 0 && "$pr_count" -eq 0 ]]; then
    AUTOMATION_BRANCH_STATE="absent"
    return 0
  fi

  if [[ "$remote_count" -eq 0 ]]; then
    AUTOMATION_OWNERSHIP_ERROR="an open Pull Request references $repo:$branch_name but the remote branch is missing"
    return 1
  fi

  if [[ "$pr_count" -eq 0 ]]; then
    AUTOMATION_OWNERSHIP_ERROR="reserved branch $repo:$branch_name exists without a matching open automation Pull Request; ownership is unproven"
    return 1
  fi

  if [[ "$pr_count" -ne 1 ]]; then
    AUTOMATION_OWNERSHIP_ERROR="expected exactly one open Pull Request for $repo:$branch_name; found $pr_count"
    return 1
  fi

  pr_number="$(jq -r '.[0].number // empty' <<< "$prs_json")"
  pr_url="$(jq -r '.[0].html_url // empty' <<< "$prs_json")"
  pr_title="$(jq -r '.[0].title // empty' <<< "$prs_json")"
  pr_body="$(jq -r '.[0].body // ""' <<< "$prs_json")"
  pr_head_sha="$(jq -r '.[0].head.sha // empty' <<< "$prs_json")"
  pr_head_ref="$(jq -r '.[0].head.ref // empty' <<< "$prs_json")"
  pr_head_repo="$(jq -r '.[0].head.repo.full_name // empty' <<< "$prs_json")"
  pr_base_ref="$(jq -r '.[0].base.ref // empty' <<< "$prs_json")"

  if [[ "$pr_head_repo" != "$repo" || "$pr_head_ref" != "$branch_name" || "$pr_base_ref" != "$base_branch" ]]; then
    AUTOMATION_OWNERSHIP_ERROR="Pull Request provenance does not match repository/head/base for $repo:$branch_name"
    return 1
  fi

  if [[ -n "$expected_title" && "$pr_title" != "$expected_title" ]]; then
    AUTOMATION_OWNERSHIP_ERROR="Pull Request #$pr_number has an unexpected title; ownership is unproven"
    return 1
  fi

  if ! grep -Fq -- "$ownership_marker" <<< "$pr_body"; then
    AUTOMATION_OWNERSHIP_ERROR="Pull Request #$pr_number is missing the required automation ownership marker"
    return 1
  fi

  if [[ "$pr_head_sha" != "$remote_sha" ]]; then
    AUTOMATION_OWNERSHIP_ERROR="Pull Request #$pr_number head SHA does not match the current remote branch SHA"
    return 1
  fi

  AUTOMATION_BRANCH_STATE="owned"
  AUTOMATION_BRANCH_SHA="$remote_sha"
  AUTOMATION_PR_NUMBER="$pr_number"
  AUTOMATION_PR_URL="$pr_url"
  return 0
}
