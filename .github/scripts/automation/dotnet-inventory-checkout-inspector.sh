#!/usr/bin/env bash
# Extracted from .github/workflows/dotnet-repository-inventory.yml; preserve job-scoped environment and trust boundary.
set -Eeuo pipefail

if [[ ! "$INSPECTOR_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error title=Invalid Inspector version::INSPECTOR_VERSION must use MAJOR.MINOR.PATCH."
  exit 1
fi

if [[ ! "$INSPECTOR_SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo "::error title=Invalid Inspector SHA::INSPECTOR_SHA must be a full 40-character commit SHA."
  exit 1
fi

rm -rf .inspector
git init --quiet .inspector
git -C .inspector remote add origin https://github.com/rodri-oliveira-dev/DotNetRepoInspector.git
git -C .inspector fetch \
  --depth 1 \
  --filter=blob:none \
  --quiet \
  origin "$INSPECTOR_SHA"
git -C .inspector checkout --detach --quiet FETCH_HEAD

resolved_sha="$(git -C .inspector rev-parse HEAD)"
if [[ "$resolved_sha" != "$INSPECTOR_SHA" ]]; then
  echo "::error title=Inspector checkout mismatch::Expected $INSPECTOR_SHA but resolved $resolved_sha."
  exit 1
fi

printf 'Using DotNetRepoInspector v%s at %s\n' "$INSPECTOR_VERSION" "$resolved_sha"
