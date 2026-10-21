# overlay/ — per-cluster overrides

This directory contains overlays for specific clusters. **Never edit `base/` for a cluster** —
always create or modify overlays here.

## The `reference` cluster

`overlay/clusters/reference/` is a **reference** (not deployed). It ships with example values
that demonstrate the structure. To create a real cluster overlay:

```bash
cp -r overlay/clusters/reference overlay/clusters/<your-cluster>
```

Then:
1. Edit `cluster-vars.yaml` with your cluster's values (or use `${VAR}` for Flux).
2. Copy `.env.example` → `.env` and fill in real values for local rendering.
3. For each provider, copy `secret-patch.yaml.example` → `secret-patch.yaml` (gitignored).
4. If using a non-default provider, change the `components:` line in the overlay Component.

## Structure

```
overlay/clusters/<cluster>/
├── cluster-vars.yaml              # ConfigMap: non-secret ${VAR} values
├── .env.example                   # .env template for local renders
├── cluster-apps/
│   ├── kustomization.yaml         # aggregator + version replacements
│   └── patches/<model>/<app>/     # Component: base ref + JSON patches
│       ├── appdeployments/<app>/
│       ├── helm-releases/<app>/
│       └── custom-crds/<app>/
│           └── providers/<provider>/
└── flux-system/
    ├── gitrepository.yaml
    └── 01-cluster-apps.yaml
```

## Version Management

The overlay's `kustomization.yaml` includes `replacements` that inject versions from
`base/versions/app-versions.configmap.yaml` into AppDeployment `spec.appRef.name` fields.
See [docs/specs/version-management.md](../../docs/specs/version-management.md).

See [PRACTICES.md](../../PRACTICES.md) for the complete overlay model.
