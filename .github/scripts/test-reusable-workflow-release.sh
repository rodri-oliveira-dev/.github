#!/usr/bin/env bash
# No credentials needed: validate the manual release contract and unsafe inputs.
set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
release=".github/scripts/release-reusable-workflows.sh"
workflow=".github/workflows/reusable-workflow-release.yml"
version_file=".github/reusable-workflows/VERSION"
[[ -s "$release" && -s "$workflow" && -s "$version_file" ]]
bash -n "$release"

grep -Fxq '  workflow_dispatch:' "$workflow"
grep -Fq 'Approved stable version declared in .github/reusable-workflows/VERSION' "$workflow"
grep -Fxq '        default: "v1.0.0"' "$workflow"
grep -Fxq "    if: github.ref == 'refs/heads/main'" "$workflow"
grep -Fxq '      contents: write' "$workflow"
grep -Fq 'RELEASE_VERSION: ${{ inputs.version }}' "$workflow"
grep -Fq 'does not match reviewed declaration' "$workflow"

if grep -Eq '^[[:space:]]+(pull_request|pull_request_target|push|schedule):' "$workflow"; then
  echo "::error::Privileged release publication must be manual-only." >&2
  exit 1
fi
if grep -Fq 'pull-requests: write' "$workflow" || grep -Fq 'pull-requests: read' "$workflow"; then
  echo "::error::Manual release does not need pull-request permissions." >&2
  exit 1
fi
if grep -Fq 'validate-reusable-workflow-release-approval.sh' "$workflow"; then
  echo "::error::Manual release must not depend on merged-PR approval provenance." >&2
  exit 1
fi
if grep -Fq 'RELEASE_TARGET_SHA:' "$workflow"; then
  echo "::error::Manual release should publish the explicitly selected main revision." >&2
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
unset RELEASE_TARGET_SHA
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
GITHUB_SHA="main" reject "non-immutable target"

if GH_TOKEN="" bash "$release" > /dev/null 2>&1; then
  echo "::error::Publishing release unexpectedly succeeded without credentials." >&2
  exit 1
fi

bash .github/scripts/test-reusable-workflow-release-order.sh
echo "Manual release trigger, reviewed VERSION declaration, stable-tag policy, and negative fixtures passed."
