#!/usr/bin/env bash
# Bounded retries for *read-only* HTTP requests in public cross-repository batches.
# Callers provide a curl GET invocation that writes its response to an output file
# and prints only the HTTP status. Mutations are deliberately excluded.

batch_retry_http_get() {
  local response_file="$1"
  shift

  local arg has_get=false
  for arg in "$@"; do
    if [[ "$arg" == "--get" ]]; then
      has_get=true
    fi
    if [[ "$arg" == "--request" || "$arg" == "--data" || "$arg" == "--data-raw" ||
          "$arg" == "--data-binary" || "$arg" == "--form" ]]; then
      echo "::error title=Unsafe HTTP retry::Only explicit GET requests may be retried." >&2
      return 2
    fi
  done
  if [[ "$has_get" != "true" ]]; then
    echo "::error title=Unsafe HTTP retry::Missing --get for read-only request." >&2
    return 2
  fi

  local attempt=1 max_attempts=3 status="" rc=0
  while (( attempt <= max_attempts )); do
    rc=0
    if status="$("$@")"; then
      if [[ ! "$status" =~ ^[0-9]{3}$ ]]; then
        echo "::error title=Unexpected HTTP response::Read-only API request returned no HTTP status." >&2
        return 1
      fi
      case "$status" in
        429|500|502|503|504)
          if (( attempt == max_attempts )); then
            printf '%s\n' "$status"
            return 0
          fi
          ;;
        *)
          printf '%s\n' "$status"
          return 0
          ;;
      esac
    else
      rc=$?
      case "$rc" in
        6|7|28|35|52|56)
          if (( attempt == max_attempts )); then
            return "$rc"
          fi
          ;;
        *)
          return "$rc"
          ;;
      esac
    fi

    # Fixed, bounded backoff: 1s, then 2s. No payload or credentials in logs.
    sleep "$attempt"
    attempt=$((attempt + 1))
  done

  return 1
}
