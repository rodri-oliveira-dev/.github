#!/usr/bin/env bash
# No credentials needed: validate the release contract and reject unsafe inputs.
set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
release=".github/scripts/release-reusable-workflows.sh"
workflow=".github/workflows/reusable-workflow-release.yml"
[[ -s "$release" && -s "$workflow" ]]
bash -n "$release"
grep -Fxq '  workflow_dispatch:' "$workflow"
grep -Fxq "    if: github.ref == 'refs/heads/main'" "$workflow"
grep -Fxq '      contents: write' "$workflow"
if grep -Eq '^[[:space:]]+(pull_request|pull_request_target|push):' "$workflow"; then
  echo "::error::Publishing releases must require manual workflow_dispatch." >&2
  exit 1
fi

export GITHUB_REPOSITORY="rodri-oliveira-dev/.github"
export GITHUB_REF="refs/heads/main"
export GITHUB_SHA="0123456789abcdef0123456789abcdef01234567"
export RELEASE_VERSION="v1.0.0"

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
GITHUB_SHA="main" reject "non-immutable target"
# Without GH_TOKEN, only --validate is allowed (even from main).
if GH_TOKEN="" bash "$release" > /dev/null 2>&1; then
  echo "::error::Publishing release unexpectedly succeeded without credentials." >&2
  exit 1
fi
echo "Release workflow restrictions, stable-tag contract, and negative fixtures passed."
