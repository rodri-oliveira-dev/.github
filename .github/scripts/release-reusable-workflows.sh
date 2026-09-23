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

tag_endpoint="repos/$repo/git/ref/tags/$version"
if existing_sha="$(gh api "$tag_endpoint" --jq '.object.sha' 2>/dev/null)"; then
  [[ "$existing_sha" == "$target" ]] ||
    die "$version already exists at $existing_sha; release tags are immutable."
else
  # Do not create a second release if an existing reference could not be read.
  if gh api "$tag_endpoint" >/dev/null 2>&1; then
    die "Cannot resolve existing $version tag."
  fi
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
