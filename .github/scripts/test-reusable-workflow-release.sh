#!/usr/bin/env bash
# No credentials needed: validate the release contract and reject unsafe inputs.
set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
release=".github/scripts/release-reusable-workflows.sh"
workflow=".github/workflows/reusable-workflow-release.yml"
version_file=".github/reusable-workflows/VERSION"
[[ -s "$release" && -s "$workflow" && -s "$version_file" ]]
bash -n "$release"
grep -Fxq '  push:' "$workflow"
grep -Fxq '      - main' "$workflow"
grep -Fxq '      - ".github/reusable-workflows/VERSION"' "$workflow"
grep -Fxq '  workflow_dispatch:' "$workflow"
grep -Fxq "    if: github.ref == 'refs/heads/main'" "$workflow"
grep -Fxq '      contents: write' "$workflow"
grep -Fq 'RELEASE_VERSION: ${{ steps.version.outputs.version }}' "$workflow"
grep -Fq 'RELEASE_TARGET_SHA: ${{ steps.version.outputs.target_sha }}' "$workflow"
if grep -Eq '^[[:space:]]+(pull_request|pull_request_target):' "$workflow"; then
  echo "::error::Privileged release publication must never run from a pull request event." >&2
  exit 1
fi
if grep -Eq '^[[:space:]]+paths-ignore:' "$workflow"; then
  echo "::error::Release publication must be scoped only by the reviewed VERSION path." >&2
  exit 1
fi

declared_version="$(cat "$version_file")"
[[ "$declared_version" =~ ^v([1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
  echo "::error::$version_file must contain one canonical stable version." >&2
  exit 1
}

export GITHUB_REPOSITORY="rodri-oliveira-dev/.github"
export GITHUB_REF="refs/heads/main"
export GITHUB_SHA="0123456789abcdef0123456789abcdef01234567"
export RELEASE_TARGET_SHA="$GITHUB_SHA"
export RELEASE_VERSION="$declared_version"

bash "$release" --validate >/dev/null

reject() {
  local label="$1"
  if bash "$release" --validate > /dev/null 2>&1; then
    printf '::error::Release validation accepted unsafe %s.\n' "$label" >&2
    exit 1
  fi
}

RELEASE_VERSION="v0.1.0" reject "zero major version"
RELEASE_VERSION="v01.0.0" reject "noncanonical major version"
RELEASE_VERSION="v1.01.0" reject "noncanonical minor version"
RELEASE_VERSION="v1.0.01" reject "noncanonical patch version"
RELEASE_VERSION="v1" reject "non-semver alias as a release"
RELEASE_VERSION="main" reject "mutable branch as a release"
GITHUB_REF="refs/heads/feature" reject "non-main branch"
GITHUB_REPOSITORY="another/repository" reject "foreign repository"
RELEASE_TARGET_SHA="main" reject "non-immutable target"
# Without GH_TOKEN, only --validate is allowed (even from main).
if GH_TOKEN="" bash "$release" > /dev/null 2>&1; then
  echo "::error::Publishing release unexpectedly succeeded without credentials." >&2
  exit 1
fi
bash .github/scripts/test-reusable-workflow-release-order.sh
echo "Release trigger, reviewed VERSION contract, stable-tag policy, and negative fixtures passed."
