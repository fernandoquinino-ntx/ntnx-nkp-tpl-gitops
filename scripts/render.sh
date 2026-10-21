#!/usr/bin/env bash
# render.sh — render ${VAR} placeholders locally with GNU envsubst (pointwise testing).
#
# Renders all overlay directories (mgmt, managed-<name>/) for a cluster.
# Mirrors what Flux `postBuild.substituteFrom` does in-cluster.
#
# Usage:
#   scripts/render.sh <cluster> [path]        # path = file | dir (default: all overlays)
#   scripts/render.sh reference
#   scripts/render.sh reference overlay/clusters/reference/mgmt
#
# Vars come from overlay/clusters/<cluster>/.env (gitignored). Copy .env.example first.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CLUSTER="${1:-}"
TARGET="${2:-}"
if [[ -z "$CLUSTER" ]]; then
  echo "usage: scripts/render.sh <cluster> [file|dir]" >&2
  exit 2
fi

ENV_FILE="overlay/clusters/${CLUSTER}/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Copy it from .env.example and fill in values." >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

if [[ -z "$TARGET" ]]; then
  # Render all overlay directories
  TARGETS=()
  [[ -d "overlay/clusters/${CLUSTER}/mgmt" ]] && TARGETS+=("overlay/clusters/${CLUSTER}/mgmt")
  [[ -d "overlay/clusters/${CLUSTER}/managed-"* ]] && for d in overlay/clusters/${CLUSTER}/managed-*/; do
    [[ -d "$d" ]] && TARGETS+=("$d")
  done
  if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "ERROR: No overlay directories found" >&2
    exit 1
  fi
else
  TARGETS=("$TARGET")
fi

OUT_DIR="/tmp/ntnx-render/${CLUSTER}"
rm -rf "$OUT_DIR"; mkdir -p "$OUT_DIR"

TOTAL=0
for TARGET_DIR in "${TARGETS[@]}"; do
  if [[ -d "$TARGET_DIR" ]]; then
    mapfile -t FILES < <(grep -rlE '\$\{[A-Z_][A-Z0-9_]*\}' "$TARGET_DIR" 2>/dev/null || true)
  elif [[ -f "$TARGET_DIR" ]]; then
    FILES=("$TARGET_DIR")
  else
    echo "ERROR: target not found: $TARGET_DIR" >&2
    exit 1
  fi

  if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "No \${VAR} placeholders found under: $TARGET_DIR"
    continue
  fi

  for f in "${FILES[@]}"; do
    vars=$(grep -oE '\$\{[A-Z_][A-Z0-9_]*\}' "$f" | sort -u | tr -d '${}' | tr '\n' ' ')
    out="$OUT_DIR/${f#./}"
    mkdir -p "$(dirname "$out")"
    envsubst "$vars" < "$f" > "$out"
    TOTAL=$((TOTAL + 1))
  done
done

echo "Rendered ${TOTAL} file(s) with ${ENV_FILE} -> $OUT_DIR"
echo "Inspect:  diff -ru <orig> $OUT_DIR   (or)  grep -rn '\\\${' $OUT_DIR"
