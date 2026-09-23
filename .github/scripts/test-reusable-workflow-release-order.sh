#!/usr/bin/env bash
# Offline regression fixtures for release ordering and mutable-major alias safety.
set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
release="$root/.github/scripts/release-reusable-workflows.sh"
fixtures="$(mktemp -d)"
trap 'rm -rf -- "$fixtures"' EXIT
mkdir -p "$fixtures/bin"
export MOCK_TAGS="$fixtures/tags"
export MOCK_CALLS="$fixtures/calls"
export MOCK_ALIAS_SHA="1111111111111111111111111111111111111111"
export GITHUB_REPOSITORY="rodri-oliveira-dev/.github"
export GITHUB_REF="refs/heads/main"
export GH_TOKEN="fake-fixture-token"
export GITHUB_SHA="3333333333333333333333333333333333333333"
export RELEASE_VERSION="v1.11.0"

cat > "$fixtures/bin/gh" <<'GH'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$MOCK_CALLS"
if [[ "$1" == api && "${2:-}" == --paginate ]]; then
  [[ "${MOCK_CATALOG_FAILURE:-false}" != true ]] || exit 1
  cat "$MOCK_TAGS"
elif [[ "$1" == api && "${2:-}" == --method ]]; then
  exit 0
elif [[ "$1" == api && "${2:-}" == "repos/$GITHUB_REPOSITORY/git/ref/tags/v1" ]]; then
  [[ -n "$MOCK_ALIAS_SHA" ]] || exit 1
  printf '%s\n' "$MOCK_ALIAS_SHA"
elif [[ "$1" == release && "${2:-}" == view ]]; then
  exit 0
elif [[ "$1" == release && "${2:-}" == create ]]; then
  exit 0
else
  printf 'Unexpected mock gh invocation: %s\n' "$*" >&2
  exit 2
fi
GH

cat > "$fixtures/bin/git" <<'GIT'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "$*" == merge-base\ --is-ancestor\ * ]]; then exit 0; fi
printf 'Unexpected mock git invocation: %s\n' "$*" >&2
exit 2
GIT
chmod +x "$fixtures/bin/gh" "$fixtures/bin/git"
export PATH="$fixtures/bin:$PATH"

write_tags() {
  : > "$MOCK_TAGS"
  printf 'v1.9.0|%s\n' "1111111111111111111111111111111111111111" >> "$MOCK_TAGS"
  printf 'v1.10.0|%s\n' "2222222222222222222222222222222222222222" >> "$MOCK_TAGS"
  # Must be ignored for the requested major line.
  printf 'v2.99.0|%s\n' "4444444444444444444444444444444444444444" >> "$MOCK_TAGS"
}
run_release() {
  : > "$MOCK_CALLS"
  bash "$release" > "$fixtures/stdout" 2> "$fixtures/stderr"
}
no_mutation() {
  if grep -Eq -- '^api --method (POST|PATCH)' "$MOCK_CALLS"; then
    echo "::error::Rejected or idempotent release unexpectedly mutated Git refs." >&2
    exit 1
  fi
}
reject_release() {
  local reason="$1" expected="$2"
  if run_release; then
    echo "::error::$reason was unexpectedly accepted." >&2
    exit 1
  fi
  grep -Fq "$expected" "$fixtures/stderr" || {
    cat "$fixtures/stderr" >&2
    echo "::error::$reason failed with an unexpected diagnostic." >&2
    exit 1
  }
  no_mutation
}

write_tags
RELEASE_VERSION="v1.9.1" reject_release "lower version after v1.10.0" "does not advance the latest v1 release (v1.10.0)"
RELEASE_VERSION="v1.10.0" reject_release "existing version with another SHA" "release tags are immutable"
RELEASE_VERSION="v1.9.0" reject_release "older release with another SHA" "does not advance the latest v1 release (v1.10.0)"

# Re-running an older exact tag at its original commit is safe, but must NOT
# roll the v1 alias back to it, even if both commits have a valid ancestry.
RELEASE_VERSION="v1.9.0" GITHUB_SHA="1111111111111111111111111111111111111111" run_release
grep -Fq 'keeping v1 on newer v1.10.0' "$fixtures/stdout"
no_mutation

# Re-running the latest tag at its original SHA remains idempotent.
RELEASE_VERSION="v1.10.0" GITHUB_SHA="2222222222222222222222222222222222222222" MOCK_ALIAS_SHA="2222222222222222222222222222222222222222" run_release
no_mutation

# Advancing the major with a new, higher SemVer still promotes its alias.
RELEASE_VERSION="v1.11.0" GITHUB_SHA="3333333333333333333333333333333333333333" run_release
grep -Fq 'Published v1.11.0' "$fixtures/stdout"
grep -Eq -- '^api --method POST .*refs/tags/v1.11.0' "$MOCK_CALLS"
grep -Fq -- "api --method PATCH repos/$GITHUB_REPOSITORY/git/refs/tags/v1 -f sha=$GITHUB_SHA" "$MOCK_CALLS"

# No catalog must never be interpreted as empty when the API fails.
MOCK_CATALOG_FAILURE=true reject_release "tag enumeration error" "Cannot enumerate existing release tags"
echo "Release SemVer monotonicity, safe reruns, alias promotion and API failure fixtures passed."
