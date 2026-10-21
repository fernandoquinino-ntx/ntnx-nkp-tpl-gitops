# ADR 0006 — Managed Cluster Pattern (NKPCluster in Git)

**Date:** 2025-01-23
**Status:** Accepted

## Context

NKP managed clusters are provisioned by applying an `NKPCluster` CR to the management cluster.
The CRD specifies Prism Central credentials, networking, sizing, and the NKP node image.
Previously this was done only via Terraform + helm charts.

## Decision

Store `base/managed-clusters/<cluster>/` manifests in git as Kustomize templates:
- `nkpcluster.yaml` — NKPCluster CR with `${VAR}` placeholders
- `secrets.yaml` — credential secrets with `PLACEHOLDER` values

The overlay patches these with cluster-specific values.

## Consequences

- **Positive:** Cluster definitions are git-tracked, reviewable, and reproducible.
  Same pattern as Day-2 apps (AppDeployments, HelmReleases).
- **Negative:** NKPCluster has 20+ fields — more cognitive load than Terraform-only.
- **Mitigation:** `base/managed-clusters/` serves as documentation for all required fields.
  `.env.example` lists all variables. PRACTICES.md documents the deployment sequence.
