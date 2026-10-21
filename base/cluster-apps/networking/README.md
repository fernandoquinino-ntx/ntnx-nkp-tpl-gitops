# Networking category

Placeholder for networking-related applications (CNI, ingress, service mesh, etc.).

Follow the same pattern as `identity-access/dex/`:

```
base/cluster-apps/networking/<app>/
├── kustomization.yaml
├── <resource>.yaml
├── providers/
│   └── <provider>/
│       ├── kustomization.yaml
│       └── <resource>.yaml
└── secrets/
    └── <secret>/
        ├── kustomization.yaml
        └── secret.yaml
```

See [ntnx-nkp-tpl-repo.md](../../../ntnx-nkp-tpl-repo.md) for complete standards.
