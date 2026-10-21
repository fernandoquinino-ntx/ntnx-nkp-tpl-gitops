# Plan — ntnx-nkp-tpl-gitops v3: Managed Cluster + Repo Rename

## Changes Summary

| Change | Details |
|---|---|
| **Repo rename** | `ntnx-nkp-tpl-gitops` → `ntnx-nkp-tpl-gitops` |
| **Managed cluster manifests** | Add `base/managed-clusters/` with NKPCluster CR + Secrets template |
| **Management cluster manifests** | Add `base/management-cluster/` with NKPCluster (management mode) + Kommander config |
| **Multi-cluster GitOps** | Add `overlay/clusters/<cluster>/mgmt/` and `overlay/clusters/<cluster>/managed-<name>/` directories |
| **Flux bootstrap** | Add `overlay/clusters/<cluster>/bootstrap/` with GitRepository + root Kustomization |
| **New ADRs** | Managed cluster pattern, multi-cluster routing, Flux bootstrap |
| **New guides** | Deploy management cluster, deploy managed cluster, multi-cluster GitOps |
| **Updated PRACTICES.md** | Add sections for managed clusters, multi-cluster routing, Flux bootstrap |

---

## Repository Rename

### Steps
1. Create new GitHub repo: `fernandoquinino-ntx/ntnx-nkp-tpl-gitops`
2. Rename local directory: `ntnx-nkp-tpl-gitops` → `ntnx-nkp-tpl-gitops`
3. Update all references to the repo name in manifests (gitrepository.yaml, README, etc.)
4. Push to new remote
5. Delete old repo (after confirmation)

### Files to Update
- `overlay/clusters/reference/flux-system/gitrepository.yaml` — repo URL
- `README.md` — repo references
- `ntnx-nkp-tpl-gitops.md` — repo name in code blocks
- Any other hardcoded repo name references

---

## Managed Cluster Manifests

### Directory Structure

```
base/managed-clusters/<cluster>/
├── kustomization.yaml
├── nkpcluster.yaml                # NKPCluster CR (mode: managed)
├── secrets.yaml                   # 3 credential secrets
└── values.yaml                    # Helm values template (for reference)
```

### What It Renders (mode: managed)

From `nkp-infra-tf/helm-charts/nkp-cluster/templates/`:

| Resource | CRD | Notes |
|---|---|---|
| `NKPCluster` | `clusters.nkp.nutanix.com/v1alpha1` | WITHOUT `kommander.d2iq.io/host: "true"` label |
| `{cluster}-pc-credentials` | `Secret` | Prism Central auth |
| `{cluster}-pc-credentials-for-csi` | `Secret` | CSI credentials |
| `{cluster}-pc-credentials-for-konnector-agent` | `Secret` | Konnector agent auth |

**NOT included** (management-only):
- `kommander-bootstrap-configuration` ConfigMap
- `global-nutanix-credentials` Secret
- `prism-central-metadata` Secret

### Template Content

```yaml
# base/managed-clusters/<cluster>/nkpcluster.yaml
apiVersion: clusters.nkp.nutanix.com/v1alpha1
kind: NKPCluster
metadata:
  name: "${MANAGED_CLUSTER_NAME}"
  namespace: "${MANAGED_CLUSTER_NAMESPACE}"  # e.g., kommander-default-workspace
spec:
  clusterName: "${MANAGED_CLUSTER_NAME}"
  clusterDomain: "${CLUSTER_DOMAIN}"
  kubernetesVersion: "${KUBERNETES_VERSION}"
  nkpVersion: "${NKP_VERSION}"
  clusterClassName: "${CLUSTER_CLASS_NAME}"
  sshPublicKey: "${SSH_PUBLIC_KEY}"
  prism:
    endpoint: "${PRISM_ENDPOINT}"
    username: "${PRISM_USERNAME}"
    passwordSecretRef:
      name: "${MANAGED_CLUSTER_NAME}-pc-credentials"
      namespace: "${MANAGED_CLUSTER_NAMESPACE}"
    prismElement: "${PRISM_ELEMENT}"
    subnet: "${PRISM_SUBNET}"
  clusterNetwork:
    podsCidr: "${PODS_CIDR}"
    servicesCidr: "${SERVICES_CIDR}"
  controlPlaneEndpointIp: "${CONTROL_PLANE_VIP}"
  serviceLoadBalancer:
    rangeStart: "${LB_RANGE_START}"
    rangeEnd: "${LB_RANGE_END}"
  controlPlane:
    replicas: ${CONTROL_PLANE_REPLICAS}
    vcpu: ${CONTROL_PLANE_VCPU}
    memoryMiB: ${CONTROL_PLANE_MEMORY}
    diskGiB: ${CONTROL_PLANE_DISK}
  workers:
    replicas: ${WORKER_REPLICAS}
    vcpu: ${WORKER_VCPU}
    memoryMiB: ${WORKER_MEMORY}
    diskGiB: ${WORKER_DISK}
  image:
    name: "${NKP_IMAGE_NAME}"
```

---

## Management Cluster Manifests

### Directory Structure

```
base/management-cluster/
├── kustomization.yaml
├── nkpcluster.yaml                # NKPCluster CR (mode: management)
├── secrets.yaml                   # 5 credential secrets
├── kommander-bootstrap-config.yaml # ConfigMap
├── kommander-installer-config.yaml  # Kommander installer config
└── dockerhub-auth.yaml            # Docker Hub registry secret
```

### What It Renders (mode: management)

| Resource | CRD | Notes |
|---|---|---|
| `NKPCluster` | `clusters.nkp.nutanix.com/v1alpha1` | WITH `kommander.d2iq.io/host: "true"` label |
| `{cluster}-pc-credentials` | `Secret` | Prism Central auth |
| `{cluster}-pc-credentials-for-csi` | `Secret` | CSI credentials |
| `{cluster}-pc-credentials-for-konnector-agent` | `Secret` | Konnector agent auth |
| `global-nutanix-credentials` | `Secret` (capx-system) | Global CAPI credentials |
| `prism-central-metadata` | `Secret` | PC UUID |
| `kommander-bootstrap-configuration` | `ConfigMap` | Bootstrap config |

---

## Multi-Cluster GitOps Structure

### Directory Structure

```
overlay/clusters/<cluster>/
├── cluster-vars.yaml
├── .env.example
├── bootstrap/                     # Flux bootstrap CRs (applied to mgmt cluster)
│   ├── gitrepository.yaml
│   ├── root-kustomization.yaml    # Syncs mgmt/ to mgmt cluster
│   └── <managed-name>-kustomization.yaml  # Syncs managed-<name>/ to managed cluster
├── mgmt/                          # Management cluster Day-2 apps
│   ├── kustomization.yaml
│   └── patches/
│       └── <model>/<app>/
└── managed-<name>/               # Workload cluster Day-2 apps
    ├── kustomization.yaml
    └── patches/
        └── <model>/<app>/
```

### How It Works

1. **Bootstrap** runs on the management cluster — creates Flux GitRepository + Kustomizations
2. **mgmt/** apps are deployed to the management cluster (namespace: `kommander`)
3. **managed-<name>/** apps are deployed to the workload cluster via:
   - Namespace: `kommander-default-workspace`
   - `clusterConfigOverrides[].clusterSelector` targeting the managed cluster name
   - Flux Kustomization points to `managed-<name>/` path

### Flux Kustomization for Managed Cluster

```yaml
# overlay/.../bootstrap/<managed-name>-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: <managed-name>-platform
  namespace: kommander
spec:
  interval: 5m
  prune: false
  sourceRef:
    kind: GitRepository
    name: ntnx-nkp-tpl-gitops
    namespace: kommander-flux
  path: ./overlay/clusters/<cluster>/managed-<name>
  dependsOn:
    - name: mgmt-platform  # waits for mgmt platform to be ready
```

---

## Actions — Step by Step

### Phase 1: Repo Rename (Day 1)
1. Create new GitHub repo: `ntnx-nkp-tpl-gitops`
2. Rename local directory
3. Update all repo name references
4. Push to new remote
5. Tag as `v3.0.0-draft`

### Phase 2: Add Managed Cluster Manifests (Day 2)
6. Create `base/managed-clusters/<cluster>/` with NKPCluster template
7. Create `base/management-cluster/` with management mode template
8. Add overlay directories: `mgmt/` and `managed-<name>/`
9. Add Flux bootstrap CRs
10. Add version variables for NKP version, k8s version, image name

### Phase 3: Update PRACTICES.md (Day 3)
11. Add Section: "Choosing Between Management and Managed Clusters"
12. Add Section: "Managed Cluster Manifest Standards"
13. Add Section: "Multi-Cluster GitOps Standards"
14. Add Section: "Flux Bootstrap Standards"
15. Update directory structure section

### Phase 4: Update Documentation (Day 4)
16. Create `docs/guides/deploy-management-cluster.md`
17. Create `docs/guides/deploy-managed-cluster.md`
18. Create `docs/guides/multi-cluster-gitops.md`
19. Create ADRs for managed cluster pattern
20. Update troubleshooting runbooks

### Phase 5: Update Scripts (Day 5)
21. Update `validate-overlay.sh` for multi-cluster structure
22. Update `render.sh` for multi-cluster paths
23. Update `verify-prune.sh` for bootstrap + multi-cluster

### Phase 6: Push to GitHub (Day 6)
24. Commit all changes
25. Push to `ntnx-nkp-tpl-gitops`
26. Tag `v3.0.0`

---

## Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Repo name** | `ntnx-nkp-tpl-gitops` | "gitops" better describes the scope (manifests + Flux, not just Kustomize) |
| **Managed cluster in same repo** | Yes — `mgmt/` and `managed-<name>/` in same overlay | Matches `nkp-infra-tf` production pattern; single source of truth |
| **NKPCluster as manifest** | Yes — in `base/managed-clusters/` | Allows git-tracked cluster definitions; Terraform only provisions infra |
| **Bootstrap CRs** | In `overlay/.../bootstrap/` | Matches production `gitops-flux/clusters/<lab>/bootstrap/` |
| **Workspace namespace** | `kommander-default-workspace` for managed apps | Matches NKP convention for workload cluster app routing |

---

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Repo rename breaks existing references | Document the rename; old repo archived |
| NKPCluster manifest is complex (20+ vars) | Provide `values.yaml` template + `.env.example` with all vars |
| Multi-cluster structure adds cognitive load | Clear directory naming (`mgmt/`, `managed-<name>/`); ADRs explain decisions |
| Bootstrap CRs need management kubeconfig | Document that bootstrap is applied manually (not via Flux) |
