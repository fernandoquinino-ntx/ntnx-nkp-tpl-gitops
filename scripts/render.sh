#!/usr/bin/env bash
# render.sh — render ${VAR} placeholders locally with GNU envsubst (pointwise testing).
#
# Mirrors what Flux `postBuild.substituteFrom` does in-cluster, so you can test a manifest
# (or a whole overlay) without applying anything.
#
# Usage:
#   scripts/render.sh <cluster> [path]        # path = file | dir (default: the cluster overlay)
#   scripts/render.sh reference base/cluster-apps/identity-access/dex/connector.yaml
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

# Whitelist only the variables referenced as ${VAR} in the target tree, so stray shell
# variables are never substituted by accident (envsubst with an explicit shell-format).
if [[ -z "$TARGET" ]]; then
  TARGET="overlay/clusters/${CLUSTER}"
fi

if [[ -d "$TARGET" ]]; then
  mapfile -t FILES < <(grep -rlE '\$\{[A-Z_][A-Z0-9_]*\}' "$TARGET" 2>/dev/null || true)
elif [[ -f "$TARGET" ]]; then
  FILES=("$TARGET")
else
  echo "ERROR: target not found: $TARGET" >&2
  exit 1
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No \${VAR} placeholders found under: $TARGET"
  exit 0
fi

OUT_DIR="/tmp/ntnx-render/${CLUSTER}"
rm -rf "$OUT_DIR"; mkdir -p "$OUT_DIR"

for f in "${FILES[@]}"; do
  vars=$(grep -oE '\$\{[A-Z_][A-Z0-9_]*\}' "$f" | sort -u | tr -d '${}' | tr '\n' ' ')
  out="$OUT_DIR/${f#./}"
  mkdir -p "$(dirname "$out")"
  envsubst "$vars" < "$f" > "$out"
done

echo "Rendered ${#FILES[@]} file(s) with ${ENV_FILE} -> $OUT_DIR"
echo "Inspect:  diff -ru <orig> $OUT_DIR   (or)  grep -rn '\\\${' $OUT_DIR"
