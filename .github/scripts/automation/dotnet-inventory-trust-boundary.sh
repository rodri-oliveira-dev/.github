#!/usr/bin/env bash
# Extracted from .github/workflows/dotnet-repository-inventory.yml; preserve job-scoped environment and trust boundary.
set -Eeuo pipefail

if [[ ! -s "$DISCOVERED_REPOSITORIES_FILE" ]]; then
  echo "::error::Sanitized discovery artifact is missing or empty."
  exit 1
fi

for credential_name in GH_TOKEN GITHUB_TOKEN DOTNET_SDK_SYNC_APP_CLIENT_ID DOTNET_SDK_SYNC_APP_PRIVATE_KEY; do
  if [[ -n "${!credential_name:-}" ]]; then
    echo "::error::Privileged credential leaked into inspection job: $credential_name"
    exit 1
  fi
done

jq -e '
  type == "array"
  and all(.[];
    (.repository | type == "string" and length > 0)
    and (.default_branch | type == "string")
    and (keys | sort == ["default_branch", "repository"])
  )
' "$DISCOVERED_REPOSITORIES_FILE" >/dev/null
