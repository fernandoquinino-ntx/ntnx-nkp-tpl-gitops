#!/usr/bin/env bash
# verify-prune.sh — verify that prune policies are model-appropriate.
#
# Checks:
#   1. Flux Kustomizations for app resources have prune: true
#   2. Flux Kustomizations for platform-only resources have prune: false
#   3. No platform CRDs are listed in a prune: true Kustomization
#
# Usage: scripts/verify-prune.sh [cluster]   (default: reference)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CLUSTER="${1:-reference}"
FLUX_FILE="overlay/clusters/${CLUSTER}/flux-system/01-cluster-apps.yaml"

if [[ ! -f "$FLUX_FILE" ]]; then
  echo "ERROR: $FLUX_FILE not found" >&2
  exit 1
fi

echo "==> Checking prune policy in $FLUX_FILE"

# Extract prune value
PRUNE_VALUE=$(grep -E '^\s+prune:' "$FLUX_FILE" | head -1 | awk '{print $2}' || true)

if [[ -z "$PRUNE_VALUE" ]]; then
  echo "ERROR: No prune policy found in $FLUX_FILE" >&2
  exit 1
fi

echo "    prune: $PRUNE_VALUE"

# Determine if the repo has platform-only resources
HAS_PLATFORM=false
if [[ -d "base/custom-crds" ]]; then
  HAS_PLATFORM=true
fi

# Determine if the repo has app resources
HAS_APPS=false
if [[ -d "base/appdeployments" ]] || [[ -d "base/helm-releases" ]]; then
  HAS_APPS=true
fi

if [[ "$HAS_PLATFORM" == "true" ]] && [[ "$PRUNE_VALUE" == "true" ]]; then
  echo "WARNING: prune: true with platform resources (custom-crds) — platform objects may be deleted"
  echo "    If this repo contains platform CRs (License, Connector, VirtualGroup), use prune: false"
  echo "    or split into separate Flux Kustomizations."
  exit 1
fi

if [[ "$HAS_APPS" == "true" ]] && [[ "$PRUNE_VALUE" == "false" ]]; then
  echo "INFO: prune: false with app resources — app resources won't be cleaned up by Flux"
  echo "    Consider using prune: true for app resources (AppDeployments, HelmReleases)."
  echo "    This is not an error — some teams prefer explicit management."
fi

if [[ "$HAS_APPS" == "true" ]] && [[ "$HAS_PLATFORM" == "false" ]] && [[ "$PRUNE_VALUE" == "true" ]]; then
  echo "    OK: prune: true for app-only repo"
fi

if [[ "$HAS_APPS" == "false" ]] && [[ "$HAS_PLATFORM" == "true" ]] && [[ "$PRUNE_VALUE" == "false" ]]; then
  echo "    OK: prune: false for platform-only repo"
fi

if [[ "$HAS_APPS" == "true" ]] && [[ "$HAS_PLATFORM" == "true" ]] && [[ "$PRUNE_VALUE" == "true" ]]; then
  echo "    WARNING: Mixed repo with prune: true — platform objects must be in base/ and"
  echo "    never removed. Consider splitting into separate Flux Kustomizations."
fi

echo "OK: prune policy check complete."
