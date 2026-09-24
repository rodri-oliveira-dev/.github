#!/usr/bin/env bash
set -uo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${OWNER:?OWNER is required}"
: "${CENTRAL_REPO:?CENTRAL_REPO is required}"

MAPPING_FILE="${MAPPING_FILE:-coderabbit-templates/repositories.json}"
REMOTE_TEMPLATE_FILE="${REMOTE_TEMPLATE_FILE:-coderabbit-templates/remote-config.yaml}"
TARGET_PATH="${TARGET_PATH:-.coderabbit.yaml}"
SYNC_BRANCH="${SYNC_BRANCH:-chore/sync-coderabbit-config}"
PR_TITLE="${PR_TITLE:-chore: sincroniza configuração do CodeRabbit}"
COMMIT_MESSAGE="${COMMIT_MESSAGE:-chore: sincroniza configuração do CodeRabbit}"
OWNERSHIP_MARKER="<!-- automation-branch-owner: coderabbit-config-sync/v1 -->"
DRY_RUN="${DRY_RUN:-false}"

TMP_DIR="$(mktemp -d)"
RESULTS_FILE="$TMP_DIR/results.tsv"
ERRORS_FILE="$TMP_DIR/errors.tsv"
NO_CHANGES_FILE="$TMP_DIR/no-changes.tsv"
trap 'rm -rf "$TMP_DIR"' EXIT

touch "$RESULTS_FILE" "$ERRORS_FILE" "$NO_CHANGES_FILE"

LAST_ERROR=""

annotation_escape() {
  local value="$1"
  value="${value//'%'/'%25'}"
  value="${value//$'\r'/'%0D'}"
  value="${value//$'\n'/'%0A'}"
  printf '%s' "$value"
}

record_error() {
  local repo="$1"
  local template="$2"
  local message="$3"

  printf '%s\t%s\t%s\n' "$repo" "$template" "$message" >> "$ERRORS_FILE"
  echo "::error title=CodeRabbit sync: $(annotation_escape "$repo")::$(annotation_escape "$message")"
}

is_not_found_error() {
  local error_file="$1"
  grep -Eq 'HTTP 404|Not Found' "$error_file"
}

api_get_optional() {
  local endpoint="$1"
  local output_file="$2"
  local error_file="$3"

  if gh api "$endpoint" > "$output_file" 2> "$error_file"; then
    return 0
  fi

  if is_not_found_error "$error_file"; then
    : > "$output_file"
    return 2
  fi

  LAST_ERROR="$(tr '\n' ' ' < "$error_file")"
  return 1
}

render_remote_config() {
  local template_name="$1"

  sed \
    -e "s|__OWNER__|${OWNER}|g" \
    -e "s|__TEMPLATE__|${template_name}|g" \
    "$REMOTE_TEMPLATE_FILE"
}

validate_inputs() {
  if [[ ! -r "$MAPPING_FILE" ]]; then
    echo "::error::Mapping file not found: $MAPPING_FILE"
    exit 1
  fi

  if [[ ! -r "$REMOTE_TEMPLATE_FILE" ]]; then
    echo "::error::Remote config template not found: $REMOTE_TEMPLATE_FILE"
    exit 1
  fi

  if ! jq -e --arg owner "$OWNER" '
    .version == 1
    and .owner == $owner
    and (.templates | type == "object")
    and ([.templates[] | .[]] | length > 0)
    and (([.templates[] | .[]] | length) == ([.templates[] | .[]] | unique | length))
  ' "$MAPPING_FILE" > /dev/null; then
    echo "::error::Invalid repositories.json: expected version 1, matching owner and unique repositories."
    exit 1
  fi

  while IFS= read -r template_name; do
    if [[ ! -r "coderabbit-templates/$template_name" ]]; then
      echo "::error::Mapped CodeRabbit template does not exist: coderabbit-templates/$template_name"
      exit 1
    fi
  done < <(jq -r '.templates | keys[]' "$MAPPING_FILE")
}

process_repository() {
  local template_name="$1"
  local repo="$2"
  local desired_file="$TMP_DIR/desired.yaml"
  local repo_json="$TMP_DIR/repo.json"
  local error_file="$TMP_DIR/error.log"
  local current_json="$TMP_DIR/current.json"
  local branch_json="$TMP_DIR/branch.json"
  local prs_json="$TMP_DIR/prs.json"
  local branch_file_json="$TMP_DIR/branch-file.json"

  LAST_ERROR=""

  if [[ "$repo" != "$OWNER/"* ]]; then
    LAST_ERROR="Repository is outside the configured owner."
    return 1
  fi

  if ! gh api "repos/$repo" > "$repo_json" 2> "$error_file"; then
    LAST_ERROR="Unable to read repository metadata: $(tr '\n' ' ' < "$error_file")"
    return 1
  fi

  if [[ "$(jq -r '.fork' "$repo_json")" == "true" ]]; then
    echo "::warning title=CodeRabbit sync: $(annotation_escape "$repo")::Repository is a fork and was skipped."
    printf '%s\t%s\tfork\n' "$repo" "$template_name" >> "$NO_CHANGES_FILE"
    return 0
  fi

  if [[ "$(jq -r '.archived' "$repo_json")" == "true" ]]; then
    echo "::warning title=CodeRabbit sync: $(annotation_escape "$repo")::Repository is archived and was skipped."
    printf '%s\t%s\tarchived\n' "$repo" "$template_name" >> "$NO_CHANGES_FILE"
    return 0
  fi

  local base_branch
  base_branch="$(jq -r '.default_branch' "$repo_json")"
  if [[ -z "$base_branch" || "$base_branch" == "null" ]]; then
    LAST_ERROR="Repository has no default branch."
    return 1
  fi

  render_remote_config "$template_name" > "$desired_file"

  local current_exists="false"
  local current_content=""
  if api_get_optional "repos/$repo/contents/$TARGET_PATH?ref=$base_branch" "$current_json" "$error_file"; then
    current_exists="true"
    if ! current_content="$(jq -r '.content' "$current_json" | tr -d '\n' | base64 --decode 2> "$error_file")"; then
      LAST_ERROR="Unable to decode existing $TARGET_PATH: $(tr '\n' ' ' < "$error_file")"
      return 1
    fi
  else
    local optional_status=$?
    if (( optional_status == 1 )); then
      LAST_ERROR="Unable to read existing $TARGET_PATH: $LAST_ERROR"
      return 1
    fi
  fi

  local desired_content
  desired_content="$(cat "$desired_file")"
  if [[ "$current_exists" == "true" && "$current_content" == "$desired_content" ]]; then
    printf '%s\t%s\tup-to-date\n' "$repo" "$template_name" >> "$NO_CHANGES_FILE"
    echo "Already up to date: $repo"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    printf '%s\t%s\tdrift-detected\n' "$repo" "$template_name" >> "$NO_CHANGES_FILE"
    echo "DRY RUN: would synchronize $repo with $template_name"
    return 0
  fi

  local branch_exists="false"
  local branch_sha=""
  if api_get_optional "repos/$repo/git/ref/heads/$SYNC_BRANCH" "$branch_json" "$error_file"; then
    branch_exists="true"
    branch_sha="$(jq -r '.object.sha' "$branch_json")"
  else
    local optional_status=$?
    if (( optional_status == 1 )); then
      LAST_ERROR="Unable to inspect reserved branch: $LAST_ERROR"
      return 1
    fi
  fi

  if ! gh api "repos/$repo/pulls?state=open&head=$OWNER:$SYNC_BRANCH&per_page=10" > "$prs_json" 2> "$error_file"; then
    LAST_ERROR="Unable to inspect existing Pull Requests: $(tr '\n' ' ' < "$error_file")"
    return 1
  fi

  local pr_count
  pr_count="$(jq 'length' "$prs_json")"

  if [[ "$branch_exists" == "true" ]]; then
    if [[ "$SYNC_BRANCH" == "$base_branch" ]]; then
      LAST_ERROR="Reserved automation branch resolves to the default branch."
      return 1
    fi

    if (( pr_count != 1 )); then
      LAST_ERROR="Reserved branch exists but does not have exactly one open automation Pull Request."
      return 1
    fi

    local existing_title existing_base existing_body existing_head
    existing_title="$(jq -r '.[0].title' "$prs_json")"
    existing_base="$(jq -r '.[0].base.ref' "$prs_json")"
    existing_body="$(jq -r '.[0].body // ""' "$prs_json")"
    existing_head="$(jq -r '.[0].head.sha' "$prs_json")"

    if [[ "$existing_title" != "$PR_TITLE" ]]; then
      LAST_ERROR="Existing Pull Request on reserved branch has an unexpected title."
      return 1
    fi
    if [[ "$existing_base" != "$base_branch" ]]; then
      LAST_ERROR="Existing Pull Request targets '$existing_base' instead of '$base_branch'."
      return 1
    fi
    if [[ "$existing_body" != *"$OWNERSHIP_MARKER"* ]]; then
      LAST_ERROR="Existing Pull Request on reserved branch is missing the ownership marker."
      return 1
    fi
    if [[ "$existing_head" != "$branch_sha" ]]; then
      LAST_ERROR="Reserved branch head does not match the Pull Request head."
      return 1
    fi
  elif (( pr_count != 0 )); then
    LAST_ERROR="Open Pull Request exists for the reserved branch, but the branch does not exist."
    return 1
  fi

  local worktree="$TMP_DIR/worktree"
  rm -rf "$worktree"

  if ! gh repo clone "$repo" "$worktree" -- --filter=blob:none --no-tags > /dev/null 2> "$error_file"; then
    LAST_ERROR="Unable to clone repository for a safe update: $(tr '\n' ' ' < "$error_file")"
    return 1
  fi

  git -C "$worktree" config user.name "github-actions[bot]"
  git -C "$worktree" config user.email "41898282+github-actions[bot]@users.noreply.github.com"

  if [[ "$branch_exists" == "true" ]]; then
    if ! git -C "$worktree" fetch origin "refs/heads/$SYNC_BRANCH:refs/remotes/origin/$SYNC_BRANCH" > /dev/null 2> "$error_file"; then
      LAST_ERROR="Unable to fetch reserved branch: $(tr '\n' ' ' < "$error_file")"
      return 1
    fi

    local fetched_branch_sha
    fetched_branch_sha="$(git -C "$worktree" rev-parse "refs/remotes/origin/$SYNC_BRANCH")"
    if [[ "$fetched_branch_sha" != "$branch_sha" ]]; then
      LAST_ERROR="Reserved branch changed after provenance validation."
      return 1
    fi

    git -C "$worktree" switch --detach "$fetched_branch_sha" > /dev/null 2>&1
    git -C "$worktree" switch -c "$SYNC_BRANCH" > /dev/null 2>&1
  else
    if [[ "$(git -C "$worktree" branch --show-current)" != "$base_branch" ]]; then
      LAST_ERROR="Clone did not resolve the expected default branch '$base_branch'."
      return 1
    fi
    git -C "$worktree" switch -c "$SYNC_BRANCH" > /dev/null 2>&1
  fi

  cp "$desired_file" "$worktree/$TARGET_PATH"
  git -C "$worktree" add -- "$TARGET_PATH"

  if git -C "$worktree" diff --cached --quiet -- "$TARGET_PATH"; then
    LAST_ERROR="Unexpected state: synchronization produced no diff on the reserved branch."
    return 1
  fi

  if ! git -C "$worktree" commit -m "$COMMIT_MESSAGE" > /dev/null 2> "$error_file"; then
    LAST_ERROR="Unable to create synchronization commit: $(tr '\n' ' ' < "$error_file")"
    return 1
  fi

  local expected_branch_sha
  expected_branch_sha="$(git -C "$worktree" rev-parse HEAD)"

  if [[ "$branch_exists" == "true" ]]; then
    if ! git -C "$worktree" push origin "HEAD:refs/heads/$SYNC_BRANCH" \
      --force-with-lease="refs/heads/$SYNC_BRANCH:$branch_sha" > /dev/null 2> "$error_file"; then
      LAST_ERROR="Reserved branch changed after provenance validation or push was rejected: $(tr '\n' ' ' < "$error_file")"
      return 1
    fi
  else
    if ! git -C "$worktree" push origin "HEAD:refs/heads/$SYNC_BRANCH" \
      --force-with-lease="refs/heads/$SYNC_BRANCH:" > /dev/null 2> "$error_file"; then
      LAST_ERROR="Unable to create reserved branch safely: $(tr '\n' ' ' < "$error_file")"
      return 1
    fi
  fi

  local pr_url status
  if (( pr_count == 1 )); then
    pr_url="$(jq -r '.[0].html_url' "$prs_json")"
    status="updated"
  else
    local pr_body
    pr_body="$(cat <<EOF
$OWNERSHIP_MARKER

## CodeRabbit configuration

Synchronizes `$TARGET_PATH` with the centrally managed **$template_name** profile.

Source:
`https://raw.githubusercontent.com/$OWNER/.github/main/coderabbit-templates/$template_name`

The local file contains only `remote_config`; review rules remain versioned in `$CENTRAL_REPO`.

This Pull Request is managed by the CodeRabbit configuration distribution workflow. Do not reuse the reserved branch for unrelated changes.
EOF
)"

    if ! pr_url="$(gh pr create \
      --repo "$repo" \
      --base "$base_branch" \
      --head "$SYNC_BRANCH" \
      --title "$PR_TITLE" \
      --body "$pr_body" 2> "$error_file")"; then

      local pr_error
      pr_error="$(tr '\n' ' ' < "$error_file")"

      # If this run created the branch and PR creation failed, clean up only when
      # the remote branch still points to the exact commit produced by this run.
      if [[ "$created_branch" == "true" && -n "$expected_branch_sha" ]]; then
        local live_sha=""
        live_sha="$(gh api "repos/$repo/git/ref/heads/$SYNC_BRANCH" --jq '.object.sha' 2>/dev/null || true)"
        if [[ "$live_sha" == "$expected_branch_sha" ]]; then
          gh api --method DELETE "repos/$repo/git/refs/heads/$SYNC_BRANCH" > /dev/null 2>&1 || true
        fi
      fi

      LAST_ERROR="Unable to open Pull Request: $pr_error"
      return 1
    fi
    status="created"
  fi

  printf '%s\t%s\t%s\t%s\n' "$repo" "$template_name" "$status" "$pr_url" >> "$RESULTS_FILE"
  echo "${status^} Pull Request: $repo -> $pr_url"
  return 0
}

write_summary() {
  local summary_file="${GITHUB_STEP_SUMMARY:-/dev/null}"
  local result_count error_count no_change_count
  result_count="$(wc -l < "$RESULTS_FILE" | tr -d ' ')"
  error_count="$(wc -l < "$ERRORS_FILE" | tr -d ' ')"
  no_change_count="$(wc -l < "$NO_CHANGES_FILE" | tr -d ' ')"

  {
    echo "## CodeRabbit configuration distribution"
    echo
    echo "- Pull Requests open/updated: **$result_count**"
    echo "- Repositories without mutation: **$no_change_count**"
    echo "- Errors: **$error_count**"
    echo

    echo "### Open Pull Requests"
    echo
    if (( result_count == 0 )); then
      echo "No Pull Request was opened or updated."
    else
      echo "| Repository | Template | Result | Pull Request |"
      echo "| --- | --- | --- | --- |"
      while IFS=$'\t' read -r repo template status url; do
        printf '| `%s` | `%s` | %s | [PR](%s) |\n' "$repo" "$template" "$status" "$url"
      done < "$RESULTS_FILE"
    fi

    if (( error_count > 0 )); then
      echo
      echo "### Errors"
      echo
      echo "| Repository | Template | Error |"
      echo "| --- | --- | --- |"
      while IFS=$'\t' read -r repo template message; do
        message="${message//|/\\|}"
        printf '| `%s` | `%s` | %s |\n' "$repo" "$template" "$message"
      done < "$ERRORS_FILE"
    fi
  } >> "$summary_file"
}

validate_inputs

while IFS=$'\t' read -r template_name repo; do
  echo "::group::CodeRabbit sync - $repo ($template_name)"
  if ! process_repository "$template_name" "$repo"; then
    record_error "$repo" "$template_name" "${LAST_ERROR:-Unknown error}"
  fi
  echo "::endgroup::"
done < <(jq -r '.templates | to_entries[] | .key as $template | .value[] | [$template, .] | @tsv' "$MAPPING_FILE")

write_summary

if [[ -s "$ERRORS_FILE" ]]; then
  echo "::error::CodeRabbit configuration distribution completed with one or more repository errors."
  exit 1
fi
