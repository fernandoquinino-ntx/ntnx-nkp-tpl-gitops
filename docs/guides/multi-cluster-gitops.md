# Guide — Multi-Cluster GitOps

This guide explains how multi-cluster GitOps works in the template: how apps are routed to
the management cluster vs. workload clusters via Flux and `clusterConfigOverrides`.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Management Cluster                                              │
│                                                                  │
│  Flux (kommander-flux namespace)                                 │
│  ├── GitRepository → reads this repo                            │
│  ├── mgmt-platform Kustomization → syncs mgmt/ to mgmt cluster  │
│  └── managed-01-platform Kustomization → syncs managed-01/ to   │
│      managed-01 cluster (via workspace membership)               │
│                                                                  │
│  AppDeployments in kommander/ namespace → deployed to mgmt-a    │
│  AppDeployments in kommander-default-workspace/ → routed to      │
│      managed-01 via clusterConfigOverrides                       │
└─────────────────────────────────────────────────────────────────┘
           │ Flux syncs manifests
           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Managed Cluster (managed-01)                                    │
│                                                                  │
│  Apps arrive via workspace membership + clusterConfigOverrides   │
│  No Flux instance needed (managed by mgmt cluster)               │
└─────────────────────────────────────────────────────────────────┘
```

## How Routing Works

### 1. Namespace Determines the Cluster

| Namespace | Cluster |
|---|---|
| `kommander` | Management cluster |
| `kommander-default-workspace` | Workload cluster (managed-01) |

### 2. clusterConfigOverrides Refines the Target

Even within the same namespace, `clusterConfigOverrides[].clusterSelector` can target
specific clusters:

```yaml
clusterConfigOverrides:
  - clusterSelector:
      matchExpressions:
        - key: kommander.d2iq.io/cluster-name
          operator: In
          values: ["mgmt-a"]     # → management cluster
    configMapName: "fluent-bit-override"
  - clusterSelector:
      matchExpressions:
        - key: kommander.d2iq.io/cluster-name
          operator: In
          values: ["managed-01"] # → workload cluster
    configMapName: "fluent-bit-override"
```

### 3. Flux Kustomizations Route Directories

| Flux Kustomization | Path | Target |
|---|---|---|
| `mgmt-platform` | `mgmt/` | Management cluster |
| `managed-01-platform` | `managed-01/` | Workload cluster |

## Directory Structure

```
overlay/clusters/<cluster>/
├── bootstrap/
│   ├── root-kustomization.yaml          # → mgmt/ on mgmt cluster
│   └── managed-01-kustomization.yaml    # → managed-01/ on managed-01
├── mgmt/
│   ├── kustomization.yaml
│   └── patches/<model>/<app>/
│       └── appdeployment-patch.yaml     # targets: ${MGMT_CLUSTER_NAME}
└── managed-01/
    ├── kustomization.yaml
    └── patches/<model>/<app>/
        └── appdeployment-patch.yaml     # targets: ${WORKLOAD_CLUSTER_NAME}
```

## Adding a New Managed Cluster

1. Create the directory: `overlay/clusters/<cluster>/managed-<new-name>/`
2. Copy patches from `managed-01/patches/`
3. Update JSON patches to use the new cluster name
4. Create the Flux Kustomization: `bootstrap/<new-name>-kustomization.yaml`
5. Add the NKPCluster manifest: `base/managed-clusters/<new-name>/`
6. Add variables to `cluster-vars.yaml`
7. Validate: `scripts/validate-overlay.sh <cluster>`

## Troubleshooting

### App not showing on managed cluster

1. Check namespace: should be `kommander-default-workspace`
2. Check `clusterConfigOverrides[].clusterSelector` matches the managed cluster name
3. Check Flux Kustomization path points to the correct directory
4. Check Flux Kustomization `dependsOn` — is `mgmt-platform` ready?

### Flux Kustomization stuck

```bash
kubectl describe kustomization <name> -n kommander
```

Check for `dependsOn` failures or `prune: false` preventing recreation.
