#!/usr/bin/env bash
set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$root/.github/scripts/dotnet-sdk-sync-policy.sh"

scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT

assert_invalid_version() {
  local version="$1"
  if validate_stable_sdk_version "$version" fixture; then
    echo "::error::Invalid SDK version was accepted: $version" >&2
    exit 1
  fi
}

for version in "" "10" "10.0" "10.0.1.2" "10.0.x" "10.0.100-preview.1" \
  "v10.0.100" "010.0.100" "10.00.100" "10.0.010"; do
  assert_invalid_version "$version"
done

for version in "0.0.0" "8.0.100" "10.0.100" "123.45.678"; do
  validate_stable_sdk_version "$version" fixture
done

sdk_update_relation "10.0.99" "10.0.100"
[[ "$SDK_UPDATE_RELATION" == "update" ]]
sdk_update_relation "10.0.100" "10.0.100"
[[ "$SDK_UPDATE_RELATION" == "current" ]]
sdk_update_relation "10.0.101" "10.0.100"
[[ "$SDK_UPDATE_RELATION" == "newer" ]]

if sdk_update_relation "9.0.999" "10.0.100"; then
  echo "::error::Cross-channel update was accepted." >&2
  exit 1
fi
grep -Fq "same major.minor channel" <<< "$SDK_POLICY_ERROR"

cat > "$scratch/releases.json" <<'JSON'
{
  "releases-index": [
    {
      "channel-version": "10.0",
      "latest-sdk": "10.0.103",
      "release-type": "lts",
      "support-phase": "active"
    },
    {
      "channel-version": "9.0",
      "latest-sdk": "9.0.999",
      "release-type": "sts",
      "support-phase": "eol"
    }
  ]
}
JSON

load_sdk_channel_metadata "$scratch/releases.json" "10.0"
[[ "$SDK_CHANNEL_STATE" == "supported" ]]
[[ "$SDK_CHANNEL_LATEST" == "10.0.103" ]]
[[ "$SDK_CHANNEL_RELEASE_TYPE" == "lts" ]]
[[ "$SDK_CHANNEL_SUPPORT_PHASE" == "active" ]]

load_sdk_channel_metadata "$scratch/releases.json" "9.0"
[[ "$SDK_CHANNEL_STATE" == "unsupported" ]]

load_sdk_channel_metadata "$scratch/releases.json" "8.0"
[[ "$SDK_CHANNEL_STATE" == "unsupported" ]]

jq '."releases-index" += [.["releases-index"][0]]' \
  "$scratch/releases.json" > "$scratch/duplicate.json"
if load_sdk_channel_metadata "$scratch/duplicate.json" "10.0"; then
  echo "::error::Ambiguous release metadata was accepted." >&2
  exit 1
fi
grep -Fq "exactly one supported entry" <<< "$SDK_POLICY_ERROR"

jq '."releases-index"[0]."latest-sdk" = "11.0.100"' \
  "$scratch/releases.json" > "$scratch/cross-channel.json"
if load_sdk_channel_metadata "$scratch/cross-channel.json" "10.0"; then
  echo "::error::Cross-channel release metadata was accepted." >&2
  exit 1
fi
grep -Fq "Release metadata for channel '10.0' is invalid" <<< "$SDK_POLICY_ERROR"

printf '{"unexpected": []}\n' > "$scratch/malformed.json"
if load_sdk_channel_metadata "$scratch/malformed.json" "10.0"; then
  echo "::error::Malformed release metadata was accepted." >&2
  exit 1
fi
grep -Fq "releases-index array" <<< "$SDK_POLICY_ERROR"

# Invalid execution modes must fail before any network discovery or mutation.
if GITHUB_WORKSPACE="$root" DRY_RUN="TRUE" \
  bash "$root/.github/scripts/automation/dotnet-sdk-sync.sh" \
  > "$scratch/invalid-mode.log" 2>&1; then
  echo "::error::Invalid DRY_RUN mode was accepted." >&2
  exit 1
fi
grep -Fq "DRY_RUN must be exactly 'true' or 'false'" "$scratch/invalid-mode.log"

echo ".NET SDK synchronization policy regression tests passed."
