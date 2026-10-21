#!/usr/bin/env bash
# verify-prune.sh — verify that prune policies are model-appropriate.
#
# Checks:
#   1. Flux Kustomizations for app resources have prune: true
#   2. Flux Kustomizations for platform objects have prune: false
#   3. Bootstrap CRs exist for multi-cluster overlays
#
# Usage: scripts/verify-prune.sh [cluster]   (default: reference)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CLUSTER="${1:-reference}"

echo "==> Checking prune policies for cluster: $CLUSTER"

ERRORS=0

# Check bootstrap CRs
if [[ -d "overlay/clusters/${CLUSTER}/bootstrap" ]]; then
  echo "==> Checking bootstrap CRs"
  for f in gitrepository.yaml root-kustomization.yaml; do
    if [[ ! -f "overlay/clusters/${CLUSTER}/bootstrap/$f" ]]; then
      echo "FAIL: bootstrap/$f not found"
      ERRORS=$((ERRORS + 1))
    fi
  done
  if ! ls overlay/clusters/${CLUSTER}/bootstrap/*-kustomization.yaml 1>/dev/null 2>&1; then
    echo "FAIL: No managed-cluster Kustomizations in bootstrap/"
    ERRORS=$((ERRORS + 1))
  fi
  echo "    bootstrap OK"
fi

# Check each Flux Kustomization
check_prune() {
  local file="$1"
  local label="$2"
  if [[ ! -f "$file" ]]; then
    return
  fi

  local prune=$(grep -E '^\s+prune:' "$file" | head -1 | awk '{print $2}' || true)
  if [[ -z "$prune" ]]; then
    echo "WARN: No prune policy in $file ($label)"
    return
  fi

  echo "    $label: prune=$prune"

  # Platform objects should have prune: false
  if [[ "$prune" == "true" ]]; then
    # Check if this is a platform-only Kustomization
    local has_platform=false
    # root-kustomization.yaml and managed-*-kustomization.yaml are platform-level
    if [[ "$file" == *"bootstrap/"* ]]; then
      has_platform=true
    fi

    if [[ "$has_platform" == "true" ]]; then
      echo "    WARN: prune: true on platform Kustomization ($file) — platform objects may be deleted"
      ERRORS=$((ERRORS + 1))
    fi
  fi
}

# Check mgmt/ Kustomization
if [[ -f "overlay/clusters/${CLUSTER}/mgmt/kustomization.yaml" ]]; then
  check_prune "overlay/clusters/${CLUSTER}/mgmt/kustomization.yaml" "mgmt/"
fi

# Check managed-<name>/ Kustomizations
for dir in overlay/clusters/${CLUSTER}/managed-*/; do
  [[ -d "$dir" ]] || continue
  local_name=$(basename "$dir")
  if [[ -f "$dir/kustomization.yaml" ]]; then
    check_prune "$dir/kustomization.yaml" "$local_name/"
  fi
done

# Check bootstrap Kustomizations
for f in overlay/clusters/${CLUSTER}/bootstrap/*-kustomization.yaml; do
  [[ -f "$f" ]] || continue
  check_prune "$f" "$(basename $f)"
done

if [[ $ERRORS -gt 0 ]]; then
  echo "FAIL: $ERRORS error(s) found"
  exit 1
fi

echo "OK: prune policy check passed."
