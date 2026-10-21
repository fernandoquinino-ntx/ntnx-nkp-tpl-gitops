#!/usr/bin/env bash
# validate-overlay.sh — build an overlay and verify every ${VAR} is declared.
#
# Checks:
#   1. `kustomize build` succeeds for each overlay directory (mgmt, managed-<name>).
#   2. every ${VAR} in the build is declared in the cluster's cluster-vars.yaml OR .env.example
#   3. bootstrap/ CRs exist if multi-cluster structure is present.
#
# Usage: scripts/validate-overlay.sh [cluster]   (default: reference)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CLUSTER="${1:-reference}"
VARS_FILE="overlay/clusters/${CLUSTER}/cluster-vars.yaml"
ENV_EXAMPLE="overlay/clusters/${CLUSTER}/.env.example"

echo "==> Validating overlay for cluster: $CLUSTER"

# Check cluster-vars.yaml exists
if [[ ! -f "$VARS_FILE" ]]; then
  echo "ERROR: $VARS_FILE not found" >&2
  exit 1
fi

# Check .env.example exists
if [[ ! -f "$ENV_EXAMPLE" ]]; then
  echo "ERROR: $ENV_EXAMPLE not found" >&2
  exit 1
fi

# Find all overlay build directories
BUILD_DIRS=()
if [[ -d "overlay/clusters/${CLUSTER}/mgmt" ]]; then
  BUILD_DIRS+=("overlay/clusters/${CLUSTER}/mgmt")
fi
if [[ -d "overlay/clusters/${CLUSTER}/managed-"* ]]; then
  for dir in overlay/clusters/${CLUSTER}/managed-*/; do
    [[ -d "$dir" ]] && BUILD_DIRS+=("$dir")
  done
fi

if [[ ${#BUILD_DIRS[@]} -eq 0 ]]; then
  echo "ERROR: No overlay directories found (mgmt/ or managed-*/)" >&2
  exit 1
fi

# Build each directory
for BUILD_DIR in "${BUILD_DIRS[@]}"; do
  echo "==> kustomize build $BUILD_DIR"
  BUILD="$(mktemp)"
  trap 'rm -f "$BUILD"' EXIT
  kustomize build --load-restrictor=LoadRestrictionsNone "$BUILD_DIR" > "$BUILD" 2>"$BUILD.err" \
    || kubectl kustomize --load-restrictor=LoadRestrictionsNone "$BUILD_DIR" > "$BUILD" 2>>"$BUILD.err"
  if [[ ! -s "$BUILD" ]]; then
    echo "FAIL: build produced no output: $BUILD_DIR"; cat "$BUILD.err"; exit 1
  fi
  echo "    build OK"

  # Check for undeclared variables
  used="$(grep -oE '\$\{[A-Z_][A-Z0-9_]*\}' "$BUILD" | tr -d '${}' | sort -u || true)"
  declared="$(
    { [[ -f "$VARS_FILE" ]] && grep -oE '^\s+[A-Z_][A-Z0-9_]*:' "$VARS_FILE" | tr -d ' :'
      [[ -f "$ENV_EXAMPLE" ]] && grep -oE '^[A-Z_][A-Z0-9_]*=' "$ENV_EXAMPLE" | tr -d '='
    } | sort -u
  )"

  undeclared="$(comm -23 <(printf '%s\n' "$used" | sed '/^$/d') <(printf '%s\n' "$declared" | sed '/^$/d') || true)"

  if [[ -n "$undeclared" ]]; then
    echo "FAIL: undeclared \${VAR} in $BUILD_DIR:"
    printf '    %s\n' $undeclared
    exit 1
  fi
done

# Check bootstrap CRs exist for multi-cluster
if [[ -d "overlay/clusters/${CLUSTER}/bootstrap" ]]; then
  echo "==> Checking bootstrap CRs"
  for f in gitrepository.yaml root-kustomization.yaml; do
    if [[ ! -f "overlay/clusters/${CLUSTER}/bootstrap/$f" ]]; then
      echo "FAIL: bootstrap/$f not found" >&2
      exit 1
    fi
  done
  # Check for at least one managed-cluster Kustomization
  if ! ls overlay/clusters/${CLUSTER}/bootstrap/*-kustomization.yaml 1>/dev/null 2>&1; then
    echo "FAIL: No managed-cluster Kustomizations found in bootstrap/" >&2
    exit 1
  fi
  echo "    bootstrap OK"
fi

echo "OK: all ${#BUILD_DIRS[@]} overlay(s) validated."
