# base/ — generic templates

Immutable, cluster-agnostic templates. **No IPs, DNs, secrets, or cluster-specific values** —
those use `${VAR}` placeholders and are set in the overlay (or pinned with a JSON patch).

## Structure

```
base/
├── versions/
│   └── app-versions.configmap.yaml   # Centralized version registry (kustomize replacements)
├── appdeployments/                   # Model 1: Kommander AppDeployments
│   └── <app>/
│       ├── kustomization.yaml
│       ├── <app>.appdeployment.yaml
│       └── configs/<app>-override.yaml
├── helm-releases/                    # Model 2: Flux HelmReleases
│   └── <app>/
│       ├── kustomization.yaml
│       ├── helmrepository.yaml
│       └── helmrelease.yaml
├── custom-crds/                      # Model 3: Custom CRDs (Dex, MetalLB, etc.)
│   └── <app>/
│       ├── kustomization.yaml
│       ├── <resource>.yaml
│       └── providers/                # Optional: swappable implementations
└── README.md
```

## Three Deployment Models

| Model | Directory | CRD | Use Case |
|---|---|---|---|
| AppDeployment | `appdeployments/` | `apps.kommander.d2iq.io/v1alpha3` | NKP ClusterApps (monitoring, logging, storage, backup) |
| HelmRelease | `helm-releases/` | `helm.toolkit.fluxcd.io/v2` | Third-party Helm charts (Vault, custom operators) |
| Custom CRD | `custom-crds/` | Various (Dex, Kommander, etc.) | Platform config (identity, networking, license) |

See [PRACTICES.md](../../PRACTICES.md) for complete standards and model selection guide.
