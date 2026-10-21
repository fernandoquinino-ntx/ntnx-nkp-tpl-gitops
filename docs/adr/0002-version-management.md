# ADR 0002 — Centralized Version Management

**Date:** 2025-01-23
**Status:** Accepted

## Context

AppDeployment versions (`spec.appRef.name`) change frequently. Hardcoding versions in each
AppDeployment makes upgrades error-prone and creates duplicate version strings across files.

## Decision

Centralize all versions in `base/versions/app-versions.configmap.yaml` and inject them into
AppDeployments via kustomize `replacements`.

```yaml
# base/versions/app-versions.configmap.yaml
data:
  fluent-bit: "fluent-bit-0.57.2"

# overlay/.../kustomization.yaml
replacements:
  - source:
      kind: ConfigMap
      name: app-versions
      fieldPath: data.fluent-bit
    targets:
      - select:
          kind: AppDeployment
          name: fluent-bit
        fieldPaths:
          - spec.appRef.name
```

## Consequences

- **Positive:** Single source of truth for versions; upgrading is one line change.
- **Negative:** Adds kustomize `replacements` complexity; not all models use versions.
- **Mitigation:** Only AppDeployments use version replacements. HelmRelease versions stay
  in overlay patches (chart versions come from HelmRepository, not a ConfigMap).
