# base/ — generic templates

Immutable, cluster-agnostic templates. **No IPs, DNs, secrets, or cluster-specific values** —
those use `${VAR}` placeholders and are set in the overlay (or pinned with a JSON patch).

## Structure

```
base/
├── versions/
│   └── app-versions.configmap.yaml   # Centralized version registry (kustomize replacements)
├── management-cluster/               # Self-managed cluster (NKPCluster mode: management)
│   ├── kustomization.yaml
│   ├── nkpcluster.yaml
│   ├── secrets.yaml
│   ├── kommander-bootstrap-config.yaml
│   ├── kommander-installer-config.yaml
│   └── dockerhub-auth.yaml
├── managed-clusters/                 # Workload clusters (NKPCluster mode: managed)
│   └── <cluster>/
│       ├── kustomization.yaml
│       ├── nkpcluster.yaml
│       └── secrets.yaml
├── appdeployments/                   # Day-2 apps: Kommander ClusterApps
│   └── <app>/
│       ├── kustomization.yaml
│       ├── <app>.appdeployment.yaml
│       └── configs/<app>-override.yaml
├── helm-releases/                    # Day-2 apps: Third-party Helm charts
│   └── <app>/
│       ├── kustomization.yaml
│       ├── helmrepository.yaml
│       └── helmrelease.yaml
├── custom-crds/                      # Day-2 apps: Custom CRDs (Dex, MetalLB, etc.)
│   └── <app>/
│       ├── kustomization.yaml
│       ├── <resource>.yaml
│       └── providers/                # Optional: swappable implementations
└── README.md
```

## Five Resource Categories

| Category | Directory | Purpose | Deployed To |
|---|---|---|---|
| Management Cluster | `management-cluster/` | NKPCluster + Kommander bootstrap | kind → self-managed cluster |
| Managed Clusters | `managed-clusters/<cluster>/` | NKPCluster for workload clusters | Management cluster's workspace ns |
| AppDeployments | `appdeployments/<app>/` | NKP ClusterApps (monitoring, logging, etc.) | mgmt or managed cluster |
| HelmReleases | `helm-releases/<app>/` | Third-party Helm charts | mgmt or managed cluster |
| Custom CRDs | `custom-crds/<app>/` | Platform config (Dex, MetalLB, etc.) | mgmt or managed cluster |

See [PRACTICES.md](../../PRACTICES.md) for complete standards.
