#!/usr/bin/env bash
set -Eeuo pipefail

: "${LOG_OPTS:?LOG_OPTS is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

readonly summary_file="${GITHUB_STEP_SUMMARY:-/dev/null}"

if [[ ! "${MAX_TARGET_MEGABYTES:-}" =~ ^[1-9][0-9]*$ ]]; then
  echo "::error title=Invalid secret-scan size policy::MAX_TARGET_MEGABYTES must be a positive integer."
  exit 2
fi

readonly max_target_bytes=$((MAX_TARGET_MEGABYTES * 1024 * 1024))
objects_file="$(mktemp)"
oversized_file="$(mktemp)"

cleanup() {
  rm -f "$objects_file" "$oversized_file"
}
trap cleanup EXIT

git rev-list --objects "$LOG_OPTS" |
  awk '{print $1}' |
  sort -u   > "$objects_file"

git cat-file --batch-check='%(objectname) %(objecttype) %(objectsize)'   < "$objects_file" |
  awk -v max_bytes="$max_target_bytes" '
    $2 == "blob" && $3 > max_bytes {
      print $1 "\t" $3
    }
  '   > "$oversized_file"

oversized_count="$(wc -l < "$oversized_file" | tr -d '[:space:]')"
largest_oversized_bytes=0

if [[ "$oversized_count" -gt 0 ]]; then
  largest_oversized_bytes="$(
    sort -t $'\t' -k2,2nr "$oversized_file" |
      head -n 1 |
      cut -f2
  )"
fi

{
  echo "oversized-count=$oversized_count"
  echo "largest-oversized-bytes=$largest_oversized_bytes"
  echo "max-target-megabytes=$MAX_TARGET_MEGABYTES"
} >> "$GITHUB_OUTPUT"

{
  echo "## Secret scan size coverage"
  echo
  echo "| Item | Value |"
  echo "| --- | ---: |"
  echo "| Scanner per-blob limit | ${MAX_TARGET_MEGABYTES} MiB |"
  echo "| Oversized tracked blobs in selected Git scope | $oversized_count |"
  echo "| Largest oversized blob | ${largest_oversized_bytes} bytes |"
  echo
} >> "$summary_file"

if [[ "$oversized_count" -gt 0 ]]; then
  echo "result=coverage-failure" >> "$GITHUB_OUTPUT"

  {
    echo "> [!CAUTION]"
    echo "> Secret scanning stopped before the scanner because one or more tracked Git blobs exceed the configured per-target limit. A clean scanner result would not prove complete coverage."
    echo
    echo "Large tracked binaries or generated artifacts are not silently exempted. Remove them from the selected Git history, reduce their size, or store future large assets through Git LFS so Git contains only the small pointer."
  } >> "$summary_file"

  echo "::error title=Secret scan coverage blocked::$oversized_count tracked Git blob(s) in the selected scope exceed ${MAX_TARGET_MEGABYTES} MiB. The workflow fails closed instead of reporting clean."
  exit 0
fi

echo "result=covered" >> "$GITHUB_OUTPUT"
echo "All tracked Git blobs in the selected scan scope are within the scanner size limit." >> "$summary_file"
