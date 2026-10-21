# ADR 0007 — Multi-Cluster GitOps in Same Repo

**Date:** 2025-01-23
**Status:** Accepted

## Context

NKP environments have a management cluster and one or more workload clusters.
Each cluster needs its own set of Day-2 app manifests. Should these live in separate repos
or the same repo?

## Decision

Store all clusters in the same repo under `overlay/clusters/<cluster>/`:
- `mgmt/` — management cluster Day-2 apps
- `managed-<name>/` — workload cluster Day-2 apps

Routing is handled by:
1. Namespace: `kommander` (mgmt) vs `kommander-default-workspace` (managed)
2. `clusterConfigOverrides[].clusterSelector` in AppDeployments
3. Separate Flux Kustomizations in `bootstrap/`

## Consequences

- **Positive:** Single source of truth; consistent structure across clusters; easier to
  compare configs between clusters; matches production `nkp-infra-tf` pattern.
- **Negative:** Larger repo; cognitive load of understanding routing.
- **Mitigation:** `docs/guides/multi-cluster-gitops.md` explains routing.
  PRACTICES.md has a routing table.
