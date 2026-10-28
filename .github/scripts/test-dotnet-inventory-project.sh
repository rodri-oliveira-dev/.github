#!/usr/bin/env bash
set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
module_dir="$root/.github/scripts/automation"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT

cat > "$scratch/report.json" <<'JSON'
{
  "schemaVersion": "1.7",
  "dotNetSdk": {
    "configured": { "version": "10.0.100" },
    "resolvedVersion": "10.0.103"
  },
  "projects": [
    {
      "path": "src/App/App.csproj",
      "name": "App",
      "resolvedSdkVersion": "10.0.102",
      "sdks": [{ "name": "Microsoft.NET.Sdk.Web" }],
      "targetFrameworks": ["net8.0", "net10.0"],
      "classification": { "kind": "web" },
      "publication": {
        "selfContained": { "state": "evaluated", "value": true },
        "publishSelfContained": { "state": "context-dependent" },
        "publishAot": { "state": "evaluated", "value": false },
        "publishTrimmed": { "state": "unspecified" },
        "runtimeFrameworkVersion": { "state": "evaluated", "value": "10.0.1" }
      },
      "diagnostics": []
    },
    {
      "path": "src/Legacy/Legacy.csproj",
      "targetFrameworks": ["net8.0"],
      "diagnostics": []
    }
  ]
}
JSON

jq -c -L "$module_dir" \
  'include "dotnet-inventory-project";
   inventory_projects("rodri-oliveira-dev/sample"; "public"; "main"; 0)' \
  "$scratch/report.json" > "$scratch/projects.jsonl"

jq -s -e '
  length == 2
  and .[0].repository == "rodri-oliveira-dev/sample"
  and .[0].target_frameworks == ["net8.0", "net10.0"]
  and .[0].configured_dotnet_sdk == "10.0.100"
  and .[0].resolved_dotnet_sdk == "10.0.102"
  and .[0].publication.selfContained.value == true
  and .[0].publication.publishSelfContained.state == "context-dependent"
  and .[0].publication.runtimeFrameworkVersion.value == "10.0.1"
  and .[1].resolved_dotnet_sdk == "10.0.103"
  and .[1].publication == {}
' "$scratch/projects.jsonl" >/dev/null

# A non-zero Inspector result must remain visible even when project-level
# diagnostics are empty.
jq -c -L "$module_dir" \
  'include "dotnet-inventory-project";
   inventory_projects("rodri-oliveira-dev/sample"; "public"; "main"; 2)' \
  "$scratch/report.json" \
  | jq -s -e 'all(.[]; .status == "warning")' >/dev/null

echo "DotNetRepoInspector 1.7 project contract regression tests passed."
