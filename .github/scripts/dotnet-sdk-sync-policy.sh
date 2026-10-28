#!/usr/bin/env bash

# Shared deterministic policy for .NET SDK synchronization.
# This file is sourced by workflows and validation harnesses.

SDK_POLICY_ERROR=""
SDK_UPDATE_RELATION=""
SDK_CHANNEL_STATE=""
SDK_CHANNEL_LATEST=""
SDK_CHANNEL_RELEASE_TYPE=""
SDK_CHANNEL_SUPPORT_PHASE=""

sdk_policy_fail() {
  SDK_POLICY_ERROR="$1"
  return 1
}

validate_stable_sdk_version() {
  local version="${1:-}"
  local label="${2:-SDK version}"

  SDK_POLICY_ERROR=""

  if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    sdk_policy_fail "$label must use stable numeric major.minor.patch format in canonical form; received '$version'."
    return 1
  fi

  return 0
}

sdk_channel() {
  local version="$1"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$version"
  printf '%s.%s\n' "$major" "$minor"
}

validate_sdk_pair() {
  local current="$1"
  local latest="$2"

  if ! validate_stable_sdk_version "$current" "Current SDK"; then
    return 1
  fi

  if ! validate_stable_sdk_version "$latest" "Latest SDK"; then
    return 1
  fi

  local current_channel latest_channel
  current_channel="$(sdk_channel "$current")"
  latest_channel="$(sdk_channel "$latest")"

  if [[ "$current_channel" != "$latest_channel" ]]; then
    sdk_policy_fail "SDK update must remain in the same major.minor channel; current '$current', latest '$latest'."
    return 1
  fi

  return 0
}

sdk_update_relation() {
  local current="$1"
  local latest="$2"

  if ! validate_sdk_pair "$current" "$latest"; then
    return 1
  fi

  SDK_UPDATE_RELATION=""

  if [[ "$current" == "$latest" ]]; then
    SDK_UPDATE_RELATION="current"
    return 0
  fi

  local current_major current_minor current_patch
  local latest_major latest_minor latest_patch
  IFS='.' read -r current_major current_minor current_patch <<< "$current"
  IFS='.' read -r latest_major latest_minor latest_patch <<< "$latest"

  # The channel is already proven equal. Compare the patch/feature-band as a
  # base-10 integer so behavior is independent of locale and sort versions.
  if (( 10#$current_patch > 10#$latest_patch )); then
    SDK_UPDATE_RELATION="newer"
  else
    SDK_UPDATE_RELATION="update"
  fi
}

load_sdk_channel_metadata() {
  local release_index="$1"
  local channel="$2"
  local rows row_count latest release_type support_phase

  SDK_POLICY_ERROR=""
  SDK_CHANNEL_STATE=""
  SDK_CHANNEL_LATEST=""
  SDK_CHANNEL_RELEASE_TYPE=""
  SDK_CHANNEL_SUPPORT_PHASE=""

  if [[ ! "$channel" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    sdk_policy_fail "SDK channel must use canonical major.minor format; received '$channel'."
    return 1
  fi

  if ! jq -e '."releases-index" | type == "array"' "$release_index" >/dev/null 2>&1; then
    sdk_policy_fail "Release metadata must contain a releases-index array."
    return 1
  fi

  if ! rows="$(
    jq -r --arg channel "$channel" '
      [
        .["releases-index"][]
        | select(.["channel-version"] == $channel)
        | select(.["support-phase"] == "active" or .["support-phase"] == "maintenance")
        | [.["latest-sdk"], .["release-type"], .["support-phase"]]
      ]
      | .[]
      | @tsv
    ' "$release_index"
  )"; then
    sdk_policy_fail "Release metadata for channel '$channel' could not be parsed."
    return 1
  fi

  if [[ -z "$rows" ]]; then
    SDK_CHANNEL_STATE="unsupported"
    return 0
  fi

  row_count="$(wc -l <<< "$rows" | tr -d '[:space:]')"
  if [[ "$row_count" != "1" ]]; then
    sdk_policy_fail "Release metadata must contain exactly one supported entry for channel '$channel'; found $row_count."
    return 1
  fi

  IFS=$'\t' read -r latest release_type support_phase <<< "$rows"
  if [[ -z "$latest" || -z "$release_type" || -z "$support_phase" ]]; then
    sdk_policy_fail "Release metadata for channel '$channel' is incomplete."
    return 1
  fi

  if ! validate_sdk_pair "$channel.0" "$latest"; then
    SDK_POLICY_ERROR="Release metadata for channel '$channel' is invalid: $SDK_POLICY_ERROR"
    return 1
  fi

  SDK_CHANNEL_STATE="supported"
  SDK_CHANNEL_LATEST="$latest"
  SDK_CHANNEL_RELEASE_TYPE="$release_type"
  SDK_CHANNEL_SUPPORT_PHASE="$support_phase"
}
