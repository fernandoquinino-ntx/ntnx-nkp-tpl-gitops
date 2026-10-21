# ADR 0008 — Flux Bootstrap Applied Manually

**Date:** 2025-01-23
**Status:** Accepted

## Context

Flux bootstrap CRs (`gitrepository.yaml`, `root-kustomization.yaml`, etc.) must be applied
to the management cluster before Flux can start syncing manifests. But these CRs are stored
in the same repo that Flux reads from — a chicken-and-egg problem.

## Decision

Store bootstrap CRs in `overlay/clusters/<cluster>/bootstrap/` and apply them **manually**
(not via Flux). Once applied, Flux starts and manages the rest of the manifests.

## Consequences

- **Positive:** Solves the chicken-and-egg problem; bootstrap is a one-time operation;
  Flux then manages Day-2 apps automatically.
- **Negative:** Bootstrap must be reapplied after repo URL changes.
- **Mitigation:** Document the bootstrap procedure in `docs/guides/`.
  `scripts/` can include a bootstrap helper script.
