#!/usr/bin/env bash

# Shared deterministic policy for .NET SDK synchronization.
# This file is sourced by workflows and validation harnesses.

SDK_POLICY_ERROR=""
SDK_UPDATE_RELATION=""

sdk_policy_fail() {
  SDK_POLICY_ERROR="$1"
  return 1
}

validate_stable_sdk_version() {
  local version="${1:-}"
  local label="${2:-SDK version}"

  SDK_POLICY_ERROR=""

  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    sdk_policy_fail "$label must use stable numeric major.minor.patch format; received '$version'."
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

  local highest
  highest="$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -n 1)"

  if [[ "$highest" == "$current" ]]; then
    SDK_UPDATE_RELATION="newer"
  else
    SDK_UPDATE_RELATION="update"
  fi
}
