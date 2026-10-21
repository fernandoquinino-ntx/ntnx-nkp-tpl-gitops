# ADR 0002 — Gitignored Secret Files + Committed *.example

**Date:** 2025-01-23
**Status:** Accepted

## Context

Secrets (passwords, API keys, client secrets) must never be committed to git. But reviewers and
agents need to know the expected structure of secret files.

## Decision

- Commit `secret-patch.yaml.example` (template with `${VAR}` references).
- Gitignore `secret-patch.yaml` (real file with actual values).
- Users copy the example before applying: `cp secret-patch.yaml.example secret-patch.yaml`.

## Consequences

- **Positive:** Structure is visible in git; real secrets are never committed; Flux can substitute `${VAR}` from `cluster-secrets`.
- **Negative:** Users must remember to copy and fill the example file before applying.
- **Mitigation:** The overlay will fail to build if `secret-patch.yaml` doesn't exist (it's referenced in `kustomization.yaml`). This provides a clear error message.
