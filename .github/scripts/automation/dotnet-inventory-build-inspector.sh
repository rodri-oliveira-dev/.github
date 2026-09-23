#!/usr/bin/env bash
# Extracted from .github/workflows/dotnet-repository-inventory.yml; preserve job-scoped environment and trust boundary.
set -Eeuo pipefail

dotnet restore "$INSPECTOR_PROJECT"
dotnet build "$INSPECTOR_PROJECT" --configuration Release --no-restore
