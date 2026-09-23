#!/usr/bin/env bash
# Explicit, reviewed promotion of a reusable-workflow contract from main.
# Must only run with contents:write on workflow_dispatch, never on untrusted PRs.
set -Eeuo pipefail

die() {
  printf '::error title=Reusable workflow release::%s\n' "$*" >&2
  exit 1
}

version="${RELEASE_VERSION:-}"
ref="${GITHUB_REF:-}"
target="${GITHUB_SHA:-}"
repo="${GITHUB_REPOSITORY:-}"

[[ "$version" =~ ^v([1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] ||
  die "RELEASE_VERSION must be vMAJOR.MINOR.PATCH with no leading zeroes."
major="v${BASH_REMATCH[1]}"
[[ "$ref" == "refs/heads/main" ]] || die "Releases must run on main."
[[ "$target" =~ ^[0-9a-f]{40}$ ]] || die "GITHUB_SHA must be a full 40-character commit SHA."
[[ "$repo" == "rodri-oliveira-dev/.github" ]] || die "Release repository does not match the control plane."

# Dry validation is safe to run in every PR without GitHub credentials.
if [[ "${1:-}" == "--validate" && $# -eq 1 ]]; then
  printf 'Release input validation passed: %s at %s.\n' "$version" "$target"
  exit 0
fi
[[ $# -eq 0 ]] || die "Usage: release-reusable-workflows.sh [--validate]"
[[ -n "${GH_TOKEN:-}" ]] || die "GH_TOKEN is required for publication."
command -v gh >/dev/null 2>&1 || die "gh CLI is required."
command -v git >/dev/null 2>&1 || die "git is required."

# Read the complete tag catalog before any mutation. A failed API request
# must never be confused with an empty repository (or a missing exact tag).
# The releases/tags listing returns peeled commit SHAs for annotated tags too.
tag_listing="$(gh api --paginate "repos/$repo/tags?per_page=100" --jq '.[] | [.name, .commit.sha] | @tsv')" ||
  die "Cannot enumerate existing release tags; refusing to publish."
existing_sha=""
versions=()
while IFS=
if ! gh release view "$version" --repo "$repo" >/dev/null 2>&1; then
  gh release create "$version" --repo "$repo" --verify-tag \
    --title "Control plane $version" --generate-notes ||
    die "Tag created, but release publication failed. Re-run at the same main commit."
fi

if [[ "$skip_alias_promotion" == true ]]; then
  printf 'Release %s already exists at %s; keeping %s on newer %s.\n' \
    "$version" "$target" "$major" "$highest_version"
  exit 0
fi

# The mutable vMAJOR convenience alias is moved only after publishing a release.
# Moving it to a divergent commit is forbidden; bump the major for breaking changes.
alias_endpoint="repos/$repo/git/ref/tags/$major"
if previous_sha="$(gh api "$alias_endpoint" --jq '.object.sha' 2>/dev/null)"; then
  if [[ "$previous_sha" != "$target" ]]; then
    git merge-base --is-ancestor "$previous_sha" "$target" ||
      die "$major is not an ancestor of the new release. Investigate before promotion."
    gh api --method PATCH "repos/$repo/git/refs/tags/$major" \
      -f sha="$target" -F force=false --silent ||
      die "Failed to promote $major; $version is published and can be consumed by SHA."
  fi
else
  gh api --method POST "repos/$repo/git/refs" \
    -f ref="refs/tags/$major" -f sha="$target" --silent ||
    die "Failed to create $major; $version is published and can be consumed by SHA."
fi
printf 'Published %s at %s and promoted %s.\n' "$version" "$target" "$major"
\t' read -r tag sha; do
  [[ "$tag" =~ ^v([1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || continue
  [[ "v${BASH_REMATCH[1]}" == "$major" ]] || continue
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] ||
    die "Cannot verify commit SHA for existing release tag $tag."
  versions+=("$tag")
  if [[ "$tag" == "$version" ]]; then
    existing_sha="$sha"
  fi
done <<< "$tag_listing"

skip_alias_promotion=false
if (( ${#versions[@]} > 0 )); then
  highest_version="$(printf '%s\n' "${versions[@]}" | LC_ALL=C sort -V | tail -n 1)"
  # Never create a lower/equal release within a major. An exact-tag,
  # same-commit rerun is allowed, but must not roll back a newer major alias.
  if [[ "$highest_version" != "$version" ]] &&
     [[ "$(printf '%s\n' "$highest_version" "$version" | LC_ALL=C sort -V | tail -n 1)" == "$highest_version" ]]; then
    [[ -n "$existing_sha" && "$existing_sha" == "$target" ]] ||
      die "$version does not advance the latest $major release ($highest_version)."
    skip_alias_promotion=true
  fi
fi

tag_endpoint="repos/$repo/git/ref/tags/$version"
if [[ -n "$existing_sha" ]]; then
  [[ "$existing_sha" == "$target" ]] ||
    die "$version already exists at $existing_sha; release tags are immutable."
else
  gh api --method POST "repos/$repo/git/refs" \
    -f ref="refs/tags/$version" -f sha="$target" --silent ||
    die "Failed to create immutable release tag $version."
fi

if ! gh release view "$version" --repo "$repo" >/dev/null 2>&1; then
  gh release create "$version" --repo "$repo" --verify-tag \
    --title "Control plane $version" --generate-notes ||
    die "Tag created, but release publication failed. Re-run at the same main commit."
fi

# The mutable vMAJOR convenience alias is moved only after publishing a release.
# Moving it to a divergent commit is forbidden; bump the major for breaking changes.
alias_endpoint="repos/$repo/git/ref/tags/$major"
if previous_sha="$(gh api "$alias_endpoint" --jq '.object.sha' 2>/dev/null)"; then
  if [[ "$previous_sha" != "$target" ]]; then
    git merge-base --is-ancestor "$previous_sha" "$target" ||
      die "$major is not an ancestor of the new release. Investigate before promotion."
    gh api --method PATCH "repos/$repo/git/refs/tags/$major" \
      -f sha="$target" -F force=false --silent ||
      die "Failed to promote $major; $version is published and can be consumed by SHA."
  fi
else
  gh api --method POST "repos/$repo/git/refs" \
    -f ref="refs/tags/$major" -f sha="$target" --silent ||
    die "Failed to create $major; $version is published and can be consumed by SHA."
fi
printf 'Published %s at %s and promoted %s.\n' "$version" "$target" "$major"
