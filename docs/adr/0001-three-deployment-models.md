# ADR 0001 — Three Deployment Models

**Date:** 2025-01-23
**Status:** Accepted

## Context

NKP/Kommander supports multiple ways to deploy applications:
- **AppDeployment** for NKP ClusterApps (monitoring, logging, storage, backup)
- **HelmRelease** for third-party Helm charts via Flux
- **Custom CRDs** for platform configuration (Dex Connectors, MetalLB, License)

A single template should support all three without forcing one model.

## Decision

Provide three parallel directories in `base/`:
- `appdeployments/` — Kommander AppDeployment CRs
- `helm-releases/` — Flux HelmRelease CRs
- `custom-crds/` — Custom CRD manifests

Each has its own structure, overlay pattern, and documentation.

## Consequences

- **Positive:** Engineers can follow the same organizational pattern regardless of deployment model.
- **Negative:** More directories to maintain; cognitive load of three patterns.
- **Mitigation:** `PRACTICES.md` has a decision flow for choosing the right model.
