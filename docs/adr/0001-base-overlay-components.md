# ADR 0001 — Base-Overlay with Kustomize Components

**Date:** 2025-01-23
**Status:** Accepted

## Context

We need a way to configure NKP/Kommander applications across multiple clusters while:
- Keeping generic templates reusable and immutable
- Allowing per-cluster overrides without duplicating entire manifests
- Supporting provider switching (e.g., AD ↔ Okta) with minimal changes

## Decision

Use Kustomize **base-overlay** pattern with **Components** (`kind: Component`):

- `base/` holds generic templates with `${VAR}` placeholders
- `overlay/clusters/<cluster>/` holds per-cluster overrides as Components
- Provider switching is done by changing one `components:` line

## Consequences

- **Positive:** Clean separation of generic vs. specific; provider switching is one-line; no manifest duplication.
- **Negative:** Requires understanding of Kustomize Components (v1alpha1); relative paths can be fragile.
- **Mitigation:** `validate-overlay.sh` catches build errors; documentation explains the pattern.
