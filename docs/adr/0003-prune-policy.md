# ADR 0003 — Model-Appropriate Prune Policy

**Date:** 2025-01-23
**Status:** Accepted

## Context

Flux `prune: true` deletes resources not found in the current manifest. For NKP, some resources
are safe to prune (AppDeployments, HelmReleases) while others are not (License, Connectors,
VirtualGroups). A blanket `prune: false` wastes resources; a blanket `prune: true` risks
deleting platform objects.

## Decision

Use model-appropriate prune policies:

| Resource Type | Prune | Reason |
|---|---|---|
| AppDeployment apps | `true` | Safe to recreate |
| HelmRelease apps | `true` | Safe to recreate |
| License CR | `false` | Platform object |
| Connector CR | `false` | Platform object |
| VirtualGroup / RBAC | `false` | Platform object |
| Custom platform CRs | `false` | Platform resource |

For mixed repos (apps + platform), use `prune: true` and rely on `dependsOn` + ordering to
ensure platform objects are created first. Or split into separate Flux Kustomizations.

## Consequences

- **Positive:** App resources are cleaned up when removed; platform objects are protected.
- **Negative:** Requires understanding which resources are "platform" vs "app".
- **Mitigation:** `scripts/verify-prune.sh` catches misconfigured prune policies.
  ADR documents the decision. PRACTICES.md has a prune policy table.
