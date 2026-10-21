#!/usr/bin/env bash
# validate-overlay.sh — build an overlay and verify every ${VAR} is declared.
#
# Checks (invariant VIII):
#   1. `kustomize build` succeeds.
#   2. every ${VAR} in the build is declared in the cluster's cluster-vars.yaml OR .env.example
#      (no UNDECLARED placeholders). A left-over ${VAR} that nobody declares is a bug.
#
# Usage: scripts/validate-overlay.sh [cluster]   (default: reference)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CLUSTER="${1:-reference}"
PATH_TO_BUILD="overlay/clusters/${CLUSTER}/cluster-apps"
VARS_FILE="overlay/clusters/${CLUSTER}/cluster-vars.yaml"
ENV_EXAMPLE="overlay/clusters/${CLUSTER}/.env.example"

if [[ ! -d "$PATH_TO_BUILD" ]]; then
  echo "ERROR: $PATH_TO_BUILD not found" >&2
  exit 1
fi

echo "==> kustomize build $PATH_TO_BUILD"
BUILD="$(mktemp)"
trap 'rm -f "$BUILD"' EXIT
kustomize build --load-restrictor=LoadRestrictionsNone "$PATH_TO_BUILD" > "$BUILD" 2>"$BUILD.err" \
  || kubectl kustomize --load-restrictor=LoadRestrictionsNone "$PATH_TO_BUILD" > "$BUILD" 2>>"$BUILD.err"
if [[ ! -s "$BUILD" ]]; then
  echo "FAIL: build produced no output"; cat "$BUILD.err"; exit 1
fi
echo "    build OK"

used="$(grep -oE '\$\{[A-Z_][A-Z0-9_]*\}' "$BUILD" | tr -d '${}' | sort -u || true)"
declared="$(
  { [[ -f "$VARS_FILE" ]] && grep -oE '^\s+[A-Z_][A-Z0-9_]*:' "$VARS_FILE" | tr -d ' :'
    [[ -f "$ENV_EXAMPLE" ]] && grep -oE '^[A-Z_][A-Z0-9_]*=' "$ENV_EXAMPLE" | tr -d '='
  } | sort -u
)"

undeclared="$(comm -23 <(printf '%s\n' "$used" | sed '/^$/d') <(printf '%s\n' "$declared" | sed '/^$/d') || true)"

if [[ -n "$undeclared" ]]; then
  echo "FAIL: undeclared \${VAR} placeholders in the build:"
  printf '    %s\n' $undeclared
  echo "    -> declare them in $VARS_FILE (non-secret) or $ENV_EXAMPLE / cluster-secrets (secret)."
  exit 1
fi

echo "OK: all $(printf '%s\n' "$used" | sed '/^$/d' | wc -l | tr -d ' ') placeholder(s) declared."
