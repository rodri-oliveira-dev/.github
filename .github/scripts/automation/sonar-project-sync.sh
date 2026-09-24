#!/usr/bin/env bash
set -Eeuo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${PROJECT_OWNER:?PROJECT_OWNER is required}"
: "${PROJECT_NUMBER:?PROJECT_NUMBER is required}"
: "${VIEW_NAME:?VIEW_NAME is required}"
: "${VIEW_FILTER:?VIEW_FILTER is required}"
: "${ISSUE_SEARCH_QUERY:?ISSUE_SEARCH_QUERY is required}"

project_query='
query($owner: String!, $number: Int!) {
  user(login: $owner) {
    projectV2(number: $number) {
      id
      title
      url
      views(first: 100) {
        nodes {
          id
          name
          number
        }
      }
    }
  }
}'

project_json="$(
  gh api graphql     -F owner="$PROJECT_OWNER"     -F number="$PROJECT_NUMBER"     -f query="$project_query"
)"

project_id="$(jq -r '.data.user.projectV2.id // empty' <<<"$project_json")"
project_title="$(jq -r '.data.user.projectV2.title // empty' <<<"$project_json")"
project_url="$(jq -r '.data.user.projectV2.url // empty' <<<"$project_json")"

if [[ -z "$project_id" ]]; then
  echo "::error title=Project not found::Could not resolve Project #$PROJECT_NUMBER for $PROJECT_OWNER."
  exit 1
fi

view_id="$(
  jq -r --arg name "$VIEW_NAME"     '.data.user.projectV2.views.nodes[] | select(.name == $name) | .id'     <<<"$project_json" | head -n 1
)"
view_number="$(
  jq -r --arg name "$VIEW_NAME"     '.data.user.projectV2.views.nodes[] | select(.name == $name) | .number'     <<<"$project_json" | head -n 1
)"

view_created="false"

if [[ -z "$view_id" ]]; then
  create_view_mutation='
  mutation($projectId: ID!, $name: String!) {
    createProjectV2View(input: {
      projectId: $projectId
      name: $name
      layout: TABLE_LAYOUT
    }) {
      projectV2View {
        id
        number
        name
      }
    }
  }'

  created_view_json="$(
    gh api graphql       -F projectId="$project_id"       -F name="$VIEW_NAME"       -f query="$create_view_mutation"
  )"

  view_id="$(jq -r '.data.createProjectV2View.projectV2View.id // empty' <<<"$created_view_json")"
  view_number="$(jq -r '.data.createProjectV2View.projectV2View.number // empty' <<<"$created_view_json")"
  view_created="true"
fi

if [[ -z "$view_id" || -z "$view_number" ]]; then
  echo "::error title=View resolution failed::Could not resolve or create the '$VIEW_NAME' view."
  exit 1
fi

update_view_mutation='
mutation($viewId: ID!, $name: String!, $filter: String!) {
  updateProjectV2View(input: {
    viewId: $viewId
    name: $name
    filter: $filter
    layout: TABLE_LAYOUT
  }) {
    projectV2View {
      id
      number
      name
    }
  }
}'

gh api graphql   -F viewId="$view_id"   -F name="$VIEW_NAME"   -F filter="$VIEW_FILTER"   -f query="$update_view_mutation"   >/dev/null

existing_ids="$(mktemp)"
search_results="$(mktemp)"
trap 'rm -f "$existing_ids" "$search_results"' EXIT

items_query='
query($owner: String!, $number: Int!, $after: String) {
  user(login: $owner) {
    projectV2(number: $number) {
      items(first: 100, after: $after) {
        nodes {
          content {
            __typename
            ... on Issue {
              id
            }
          }
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  }
}'

cursor=""
while :; do
  if [[ -n "$cursor" ]]; then
    page="$(
      gh api graphql         -F owner="$PROJECT_OWNER"         -F number="$PROJECT_NUMBER"         -F after="$cursor"         -f query="$items_query"
    )"
  else
    page="$(
      gh api graphql         -F owner="$PROJECT_OWNER"         -F number="$PROJECT_NUMBER"         -f query="$items_query"
    )"
  fi

  jq -r '
    .data.user.projectV2.items.nodes[]
    | .content
    | select(.__typename == "Issue")
    | .id
  ' <<<"$page" >>"$existing_ids"

  has_next="$(jq -r '.data.user.projectV2.items.pageInfo.hasNextPage' <<<"$page")"
  [[ "$has_next" == "true" ]] || break

  cursor="$(jq -r '.data.user.projectV2.items.pageInfo.endCursor // empty' <<<"$page")"
  [[ -n "$cursor" ]] || break
done

sort -u -o "$existing_ids" "$existing_ids"

search_query='
query($query: String!, $after: String) {
  search(query: $query, type: ISSUE, first: 100, after: $after) {
    issueCount
    nodes {
      ... on Issue {
        id
        url
      }
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}'

cursor=""
total_found=0

while :; do
  if [[ -n "$cursor" ]]; then
    page="$(
      gh api graphql         -F query="$ISSUE_SEARCH_QUERY"         -F after="$cursor"         -f query="$search_query"
    )"
  else
    page="$(
      gh api graphql         -F query="$ISSUE_SEARCH_QUERY"         -f query="$search_query"
    )"
  fi

  if [[ "$total_found" -eq 0 ]]; then
    total_found="$(jq -r '.data.search.issueCount // 0' <<<"$page")"
  fi

  jq -r '
    .data.search.nodes[]
    | select(.id != null and .url != null)
    | [.id, .url]
    | @tsv
  ' <<<"$page" >>"$search_results"

  has_next="$(jq -r '.data.search.pageInfo.hasNextPage' <<<"$page")"
  [[ "$has_next" == "true" ]] || break

  cursor="$(jq -r '.data.search.pageInfo.endCursor // empty' <<<"$page")"
  [[ -n "$cursor" ]] || break
done

sort -u -o "$search_results" "$search_results"

add_item_mutation='
mutation($projectId: ID!, $contentId: ID!) {
  addProjectV2ItemById(input: {
    projectId: $projectId
    contentId: $contentId
  }) {
    item {
      id
    }
  }
}'

added=0
already_present=0
failed=0

while IFS=$'\t' read -r issue_id issue_url; do
  [[ -n "$issue_id" ]] || continue

  if grep -Fxq "$issue_id" "$existing_ids"; then
    already_present=$((already_present + 1))
    continue
  fi

  if gh api graphql     -F projectId="$project_id"     -F contentId="$issue_id"     -f query="$add_item_mutation"     >/dev/null; then
    added=$((added + 1))
    printf '%s\n' "$issue_id" >>"$existing_ids"
    echo "Added: $issue_url"
  else
    failed=$((failed + 1))
    echo "::warning title=Project item sync failed::Could not add $issue_url to Project #$PROJECT_NUMBER."
  fi
done <"$search_results"

view_url="https://github.com/users/$PROJECT_OWNER/projects/$PROJECT_NUMBER/views/$view_number"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## Sonar Project Sync"
    echo
    echo "- Project: [$project_title]($project_url)"
    echo "- View: [$VIEW_NAME]($view_url)"
    echo "- View created in this run: $view_created"
    echo "- Matching open issues: $total_found"
    echo "- Added: $added"
    echo "- Already present: $already_present"
    echo "- Failed: $failed"
    echo
    echo 'Search query:'
    echo
    echo '```text'
    echo "$ISSUE_SEARCH_QUERY"
    echo '```'
  } >>"$GITHUB_STEP_SUMMARY"
fi

if [[ "$failed" -gt 0 ]]; then
  exit 1
fi
