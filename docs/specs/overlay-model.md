# Spec — Overlay model (base → cluster)

Two layers: **`base/`** holds generic templates; **`overlay/clusters/<cluster>/`** holds the
per-cluster specifics. The overlay never re-declares what `base/` already defines — it overrides.

## Layout
```
overlay/clusters/<cluster>/
├── cluster-vars.yaml                     # ${VAR} values (ConfigMap)
├── .env.example                          # ${VAR} values for scripts/render.sh
├── cluster-apps/
│   ├── kustomization.yaml                # aggregator + replacements (versions)
│   └── patches/<model>/<app>/            # self-contained Component
└── flux-system/                          # GitRepository + Flux Kustomization(s)
```

## The aggregator (only links + replacements)
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
components:
  - patches/appdeployments/<app>
  - patches/helm-releases/<app>
  - patches/custom-crds/<app>

# Version replacements (AppDeployments only)
replacements:
  - source:
      kind: ConfigMap
      name: app-versions
      fieldPath: data.<app>
    targets:
      - select:
          kind: AppDeployment
          name: <app>
        fieldPaths:
          - spec.appRef.name
```

## Per-app Components (self-contained)
Each `patches/<model>/<app>/` is a kustomize **Component** that brings in its own base app and
declares its overrides:
```yaml
apiVersion: kustomize.config.k8s.io/v1alpha1   # Components use v1alpha1, NOT v1beta1
kind: Component
resources:
  - ../../../../../../../base/<model>/<app>
patches:
  - path: patch.yaml
    target: { group: <api-group>, version: <version>, kind: <Kind>, name: <name> }
```
> A Component built on its own emits **no output** — build the parent aggregator
> (`scripts/validate-overlay.sh <cluster>`).

## Flux entrypoint
`flux-system/gitrepository.yaml` (source) + `flux-system/01-cluster-apps.yaml` (the Kustomization
that syncs `cluster-apps` and runs `${VAR}` substitution via `postBuild.substituteFrom`).

**Prune policy:**
- App resources: `prune: true` (safe to recreate)
- Platform objects: `prune: false` (never auto-delete)

## The `reference` cluster
`overlay/clusters/reference/` is a **reference** (not deployed). Copy it to
`overlay/clusters/<your-cluster>` and edit — see `overlay/README.md`.
