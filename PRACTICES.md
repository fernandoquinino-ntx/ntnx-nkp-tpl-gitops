# PRACTICES — NKP GitOps Standards

> **Read this first.** This document is the standalone reference for configuring NKP with Kustomize + Flux GitOps. It covers all deployment models, cluster types, and multi-cluster routing.
>
> For the complete technical reference (800+ lines with agentic instructions), see [ntnx-nkp-tpl-gitops.md](ntnx-nkp-tpl-gitops.md).

---

## 1. Core Principles

| Principle | Rule | Why |
|---|---|---|
| **Separation of concerns** | `base/` = generic templates. `overlay/` = per-cluster overrides. Never edit `base/` for a cluster. | Reusability, no merge conflicts |
| **Placeholders, not values** | `base/` uses `${VAR}` for everything that differs per cluster. Overlay provides concrete values. | One template, many clusters |
| **Components, not resources** | Overlay patches use `kind: Component` with `components:` in the aggregator. | Swappability, clean hierarchy |
| **JSON patches, not declarations** | Override fields with RFC 6902 JSON patches (`op: replace`). Don't re-declare whole resources. | Minimal diffs, easy review |
| **Secrets out of git** | Real secrets are gitignored. `*.example` templates are committed. | Security, auditability |
| **Prune by risk** | App resources: `prune: true`. Platform objects (License, Connector, NKPCluster): `prune: false`. | Prevent accidental deletion |

---

## 2. Directory Structure

Every repo MUST follow this structure:

```
<repo>/
├── PRACTICES.md                     # ← You are here
├── ntnx-nkp-tpl-gitops.md           # Complete technical reference
├── CHANGELOG.md                     # Version history
├── .gitignore
│
├── base/                            # GENERIC templates (immutable)
│   ├── versions/
│   │   └── app-versions.configmap.yaml   # Centralized version registry
│   ├── management-cluster/          # Self-managed cluster (NKPCluster mode: management)
│   │   ├── kustomization.yaml
│   │   ├── nkpcluster.yaml
│   │   ├── secrets.yaml
│   │   ├── kommander-bootstrap-config.yaml
│   │   ├── kommander-installer-config.yaml
│   │   └── dockerhub-auth.yaml
│   ├── managed-clusters/            # Workload clusters (NKPCluster mode: managed)
│   │   └── <cluster>/
│   │       ├── kustomization.yaml
│   │       ├── nkpcluster.yaml
│   │       └── secrets.yaml
│   ├── appdeployments/              # Day-2 apps: Kommander ClusterApps
│   │   └── <app>/
│   │       ├── kustomization.yaml
│   │       ├── <app>.appdeployment.yaml
│   │       └── configs/
│   │           └── <app>-override.yaml
│   ├── helm-releases/               # Day-2 apps: Third-party Helm charts
│   │   └── <app>/
│   │       ├── kustomization.yaml
│   │       ├── helmrepository.yaml
│   │       └── helmrelease.yaml
│   ├── custom-crds/                 # Day-2 apps: Custom CRDs
│   │   └── <app>/
│   │       ├── kustomization.yaml
│   │       ├── <resource>.yaml
│   │       └── providers/
│   └── README.md
│
├── overlay/                         # PER-CLUSTER overrides
│   └── clusters/
│       └── reference/               # 🔑 REFERENCE cluster — copy for real clusters
│           ├── cluster-vars.yaml    # ConfigMap: non-secret ${VAR} values
│           ├── .env.example         # .env template for local renders
│           ├── bootstrap/           # Flux bootstrap CRs (applied to mgmt cluster)
│           │   ├── gitrepository.yaml
│           │   ├── root-kustomization.yaml       # Syncs mgmt/ → mgmt cluster
│           │   └── <managed-name>-kustomization.yaml  # Syncs managed-<name>/ → managed
│           ├── mgmt/                # Management cluster Day-2 apps
│           │   ├── kustomization.yaml
│           │   └── patches/<model>/<app>/
│           └── managed-<name>/      # Workload cluster Day-2 apps
│               ├── kustomization.yaml
│               └── patches/<model>/<app>/
│
├── scripts/
│   ├── validate-overlay.sh
│   ├── render.sh
│   └── verify-prune.sh
│
├── docs/
│   ├── adr/
│   ├── guides/
│   └── specs/
│
└── troubleshooting/
```

### Rules

1. **One directory per app** under `base/<category>/<app>/`.
2. **Each directory has its own `kustomization.yaml`**.
3. **Providers go under `providers/`** only when you need swappable implementations.
4. **`overlay/clusters/reference/` is required** — no real cluster overlay exists until copied.
5. **`bootstrap/` is required** in multi-cluster overlays.

---

## 3. Resource Categories — Choosing the Right One

| Category | Use When... | Example |
|---|---|---|
| **Management Cluster** | Deploying a self-managed NKP cluster (kind → pivot → Kommander) | First cluster in the environment |
| **Managed Clusters** | Deploying a workload cluster managed by the management cluster | Additional clusters for workloads |
| **AppDeployment** | Deploying an NKP ClusterApp from the Kommander catalog | `fluent-bit`, `kube-prometheus-stack`, `velero` |
| **HelmRelease** | Deploying a third-party Helm chart via Flux | `vault-operator`, `ingress-nginx` |
| **Custom CRD** | Configuring platform objects that are CRs but not AppDeployments | Dex Connectors, VirtualGroups, MetalLB |

### Decision Flow

```
Is this the first (management) cluster?
  → YES → Use management-cluster/ (NKPCluster mode: management)
  → NO  → Is this a workload cluster?
    → YES → Use managed-clusters/<name>/ (NKPCluster mode: managed)
    → NO  → Is this a Day-2 app?
      → YES → Is it an NKP ClusterApp?
        → YES → Use appdeployments/<app>/
        → NO  → Is it a Helm chart?
          → YES → Use helm-releases/<app>/
          → NO  → Use custom-crds/<app>/
```

---

## 4. Base Layer Standards (All Categories)

### 4.1 Variable Naming

- **Format:** `UPPERCASE_WITH_UNDERSCORES`
- **Prefix:** `<CATEGORY>_<FIELD>` (e.g., `FLUENT_BIT_IMAGE_TAG`, `PRISM_ENDPOINT`)
- **Cluster-specific:** `MGMT_CLUSTER_NAME`, `MANAGED_CLUSTER_NAME`, `WORKLOAD_CLUSTER_NAME`

### 4.2 Variable Declaration

| Type | Where declared | Example |
|---|---|---|
| Non-secret | `overlay/clusters/<cluster>/cluster-vars.yaml` (ConfigMap) | `FLUENT_BIT_IMAGE_TAG: "3.1.6"` |
| Secret | `cluster-secrets` Secret (referenced in Flux postBuild) | `PRISM_PASSWORD` |
| Both | `overlay/clusters/<cluster>/.env.example` | `FLUENT_BIT_IMAGE_TAG="3.1.6"` |

### 4.3 Kustomization Files

Every `kustomization.yaml` in `base/` MUST:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
# Comment explaining what this directory contains
resources:
  - <resource>.yaml
# NO secretGenerator — use plain Secret + stringData
```

### 4.4 Resource Files

Every CR in `base/` MUST:

- Use `${VAR}` for cluster-specific values
- Include inline comments for each field
- Have a stable `metadata.name` (never `${VAR}`)
- Be placed in the appropriate `base/<category>/<app>/` directory

### 4.5 Secret Templates

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <name>
  namespace: <namespace>
type: Opaque
stringData:
  key: "PLACEHOLDER_VALUE"     # NEVER a real secret
```

---

## 5. Management Cluster Standards

### 5.1 What It Renders (mode: management)

| Resource | CRD | Notes |
|---|---|---|
| `NKPCluster` | `clusters.nkp.nutanix.com/v1alpha1` | WITH `kommander.d2iq.io/host: "true"` label |
| 3x `{cluster}-pc-credentials*` | `Secret` | Prism Central auth |
| `global-nutanix-credentials` | `Secret` (capx-system) | Global CAPI credentials |
| `prism-central-metadata` | `Secret` | PC UUID |
| `kommander-bootstrap-configuration` | `ConfigMap` | Bootstrap config |

### 5.2 Key Variables

| Variable | Purpose |
|---|---|
| `MGMT_CLUSTER_NAME` | Name of the management cluster |
| `MGMT_CLUSTER_NAMESPACE` | Namespace (usually `kommander`) |
| `PRISM_ENDPOINT` | Prism Central FQDN/IP |
| `PRISM_USERNAME` / `PRISM_PASSWORD` | PC credentials |
| `PRISM_UUID` | Prism Central UUID (immutable) |
| `CONTROL_PLANE_VIP` | kube-vip VIP for API server |
| `LB_RANGE_START` / `LB_RANGE_END` | MetalLB IP range |
| `NKP_IMAGE_NAME` | NKP node image name in PC |
| `KUBERNETES_VERSION` | e.g., `v1.35.2` |
| `NKP_VERSION` | e.g., `v2.18.0` |
| `DOCKERHUB_USERNAME` / `DOCKERHUB_PASSWORD` | OCI auth |

### 5.3 Deployment Sequence

1. `nkp create bootstrap` — creates local kind cluster
2. Apply `base/management-cluster/` manifests to kind cluster
3. Wait for CAPI machines Ready
4. `nkp get kubeconfig` — extract workload kubeconfig
5. `nkp create capi-components` — deploy CAPI to workload
6. `nkp move capi-resources` — pivot from kind → workload
7. `nkp delete bootstrap` — remove kind cluster
8. `nkp install kommander` — install Kommander platform

---

## 6. Managed Cluster Standards

### 6.1 What It Renders (mode: managed)

| Resource | CRD | Notes |
|---|---|---|
| `NKPCluster` | `clusters.nkp.nutanix.com/v1alpha1` | WITHOUT `kommander.d2iq.io/host: "true"` label |
| 3x `{cluster}-pc-credentials*` | `Secret` | Prism Central auth |

**NOT included** (management-only):
- `kommander-bootstrap-configuration` ConfigMap
- `global-nutanix-credentials` Secret
- `prism-central-metadata` Secret

### 6.2 Key Variables

Same as management cluster plus:
| Variable | Purpose |
|---|---|
| `MANAGED_CLUSTER_NAME` | Name of the workload cluster |
| `MANAGED_CLUSTER_NAMESPACE` | Workspace namespace (e.g., `kommander-default-workspace`) |

### 6.3 Deployment Sequence

1. Apply `base/managed-clusters/<name>/` manifests to the **management cluster** (NOT the managed cluster)
2. Wait for `status.phase = Provisioned`
3. Extract kubeconfig from `{cluster}-kubeconfig` Secret
4. Bootstrap Flux on the managed cluster (optional, for Day-2 apps)

---

## 7. AppDeployment Standards

### 7.1 Directory Structure

```
base/appdeployments/<app>/
├── kustomization.yaml
├── <app>.appdeployment.yaml
└── configs/
    └── <app>-override.yaml      # Helm values ConfigMap
```

### 7.2 AppDeployment Template

```yaml
apiVersion: apps.kommander.d2iq.io/v1alpha3
kind: AppDeployment
metadata:
  name: <app>
  namespace: kommander             # mgmt cluster: kommander
  # OR
  # namespace: kommander-default-workspace  # managed cluster: workspace ns
spec:
  appRef:
    appID: <catalog-app-id>
    kind: ClusterApp
    name: "${<APP>_APP_REF}"
    namespace: kommander
  configOverrides:
    name: "<app>-override"
  clusterConfigOverrides:
    - clusterSelector:
        matchExpressions:
          - key: kommander.d2iq.io/cluster-name
            operator: In
            values: ["${MGMT_CLUSTER_NAME}"]
      configMapName: "<app>-override"
```

### 7.3 Version Management

Versions are centralized in `base/versions/app-versions.configmap.yaml` and injected via kustomize `replacements` in the overlay.

### 7.4 Cluster Routing

For apps deployed to **multiple clusters**:

```yaml
clusterConfigOverrides:
  - clusterSelector:
      matchExpressions:
        - key: kommander.d2iq.io/cluster-name
          operator: In
          values: ["mgmt-a"]
    configMapName: "fluent-bit-override"
  - clusterSelector:
      matchExpressions:
        - key: kommander.d2iq.io/cluster-name
          operator: In
          values: ["managed-01"]
    configMapName: "fluent-bit-override"
```

---

## 8. HelmRelease Standards

### 8.1 Directory Structure

```
base/helm-releases/<app>/
├── kustomization.yaml
├── helmrepository.yaml
└── helmrelease.yaml
```

### 8.2 Template

```yaml
# helmrepository.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: <app>
  namespace: <namespace>
spec:
  type: oci
  interval: 5m
  url: "${<APP>_HELM_REPO_URL}"

# helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: <app>
  namespace: <namespace>
spec:
  interval: 5m
  chart:
    spec:
      chart: <chart-name>
      version: "${<APP>_CHART_VERSION}"
      sourceRef:
        kind: HelmRepository
        name: <app>
        namespace: <namespace>
      interval: 5m
  install:
    createNamespace: true
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
  values:
    someSetting: "${<APP>_SOME_SETTING}"
```

---

## 9. Custom CRD Standards

### 9.1 Directory Structure

```
base/custom-crds/<app>/
├── kustomization.yaml
├── <resource>.yaml
└── providers/
    └── <provider>/
        ├── kustomization.yaml
        └── <resource>.yaml
```

### 9.2 Provider Switching

```yaml
# overlay/.../kustomization.yaml
components:
  - providers/ad    # ← default
  # OR
  - providers/okta  # ← switch
```

---

## 10. Multi-Cluster GitOps Standards

### 10.1 Directory Layout

```
overlay/clusters/<cluster>/
├── bootstrap/                     # Flux bootstrap CRs (applied to mgmt cluster)
│   ├── gitrepository.yaml
│   ├── root-kustomization.yaml    # Syncs mgmt/ → mgmt cluster
│   └── <managed-name>-kustomization.yaml  # Syncs managed-<name>/ → managed
├── mgmt/                          # Management cluster Day-2 apps
│   ├── kustomization.yaml
│   └── patches/<model>/<app>/
└── managed-<name>/               # Workload cluster Day-2 apps
    ├── kustomization.yaml
    └── patches/<model>/<app>/
```

### 10.2 How Routing Works

| Directory | Namespace | clusterSelector | Flux Kustomization |
|---|---|---|---|
| `mgmt/` | `kommander` | `${MGMT_CLUSTER_NAME}` | `root-kustomization.yaml` |
| `managed-<name>/` | `kommander-default-workspace` | `${WORKLOAD_CLUSTER_NAME}` | `<name>-kustomization.yaml` |

### 10.3 Flux Kustomization for Managed Cluster

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: <managed-name>-platform
  namespace: kommander
spec:
  interval: 5m
  prune: false                         # Platform objects — never auto-delete
  sourceRef:
    kind: GitRepository
    name: ntnx-nkp-tpl-gitops
    namespace: kommander-flux
  path: ./overlay/clusters/<cluster>/managed-<name>
  dependsOn:
    - name: mgmt-platform              # waits for mgmt platform to be ready
```

---

## 11. Bootstrap Standards

### 11.1 What Bootstrap Does

The `bootstrap/` directory contains Flux CRs that are applied **manually** to the management cluster (not via Flux). They tell Flux where to read manifests from and which directories to sync.

### 11.2 Bootstrap CRs

| CR | Purpose | Applied To |
|---|---|---|
| `gitrepository.yaml` | Tells Flux where to read this repo | `kommander-flux` namespace |
| `root-kustomization.yaml` | Syncs `mgmt/` to management cluster | `kommander` namespace |
| `<name>-kustomization.yaml` | Syncs `managed-<name>/` to managed cluster | `kommander` namespace |

### 11.3 Applying Bootstrap

```bash
# 1. Get the management cluster kubeconfig
export KUBECONFIG=<mgmt-kubeconfig>

# 2. Create the kommander-flux namespace
kubectl create namespace kommander-flux

# 3. Create GitHub App auth secret (out-of-band)
kubectl create secret generic github-app-auth -n kommander-flux --from-literal=...

# 4. Apply bootstrap CRs
kubectl apply -f overlay/clusters/<cluster>/bootstrap/gitrepository.yaml
kubectl apply -f overlay/clusters/<cluster>/bootstrap/root-kustomization.yaml
kubectl apply -f overlay/clusters/<cluster>/bootstrap/<managed-name>-kustomization.yaml
```

---

## 12. Flux Best Practices

### 12.1 Prune Policy

| Resource Type | Prune | Reason |
|---|---|---|
| AppDeployment apps | `true` | Safe to recreate |
| HelmRelease apps | `true` | Safe to recreate |
| License CR | `false` | Platform object |
| Connector CR | `false` | Platform object |
| VirtualGroup / RBAC | `false` | Platform object |
| NKPCluster | `false` | Platform object |
| Custom platform CRs | `false` | Platform resource |
| App-specific Secrets | `true` | App resource |
| Platform Secrets | `false` | Platform resource |

### 12.2 postBuild Substitution

```yaml
spec:
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-vars
      - kind: Secret
        name: cluster-secrets
        optional: true
```

### 12.3 Resource Ordering

ConfigMaps MUST be listed before AppDeployments that reference them.

### 12.4 Flux Kustomization Settings

```yaml
spec:
  prune: true|false
  validation: client
  wait: true
  timeout: 5m|10m
  dependsOn:
    - name: <dependency>
```

---

## 13. Secret Management

### 13.1 Rules

- **NEVER** commit real secrets
- **ALWAYS** commit `*.example` templates
- Use `stringData` (not `secretGenerator`)
- Gitignore: `secret-patch.yaml`, `secret.yaml`, `.env`
- Commit: `secret-patch.yaml.example`, `secret.yaml.example`, `.env.example`

### 13.2 Secret Key Conventions

| Secret Type | Keys |
|---|---|
| LDAP bind | `password` |
| OIDC client | `client-id`, `client-secret` |
| PC credentials | `username`, `password` |
| CA certificate | `tls.crt` |
| Docker Hub | `username`, `password` |

---

## 14. Validation Checklist

Before committing any change:

```bash
# 1. Validate the reference overlay
scripts/validate-overlay.sh reference

# 2. Render the reference overlay locally
scripts/render.sh reference

# 3. Verify prune policies
scripts/verify-prune.sh reference

# 4. Check for undeclared variables
grep -r '\${[A-Z_][A-Z0-9_]*}' overlay/ --include='*.yaml' | sort -u

# 5. Verify no secrets are committed
git ls-files | grep -E '(secret|password|token|key)\.yaml$' | grep -v '\.example'

# 6. Verify all .example files are committed
git ls-files | grep '\.example$'
```

---

## 15. Anti-Patterns

| Anti-Pattern | Why It's Wrong | Correct Approach |
|---|---|---|
| Concrete values in `base/` | Breaks reusability | Use `${VAR}`, set in overlay |
| `secretGenerator` | Base64-encodes values, hiding `${VAR}` | Use `stringData` |
| Editing `base/` for a cluster | Causes merge conflicts | Create overlay patches |
| `resources:` for overlay patches | Mixes patches with base | Use `components:` |
| `v1alpha1` in base Kustomizations | Wrong API version | Use `v1beta1` in base |
| Committing real secrets | Security risk | Commit `*.example`, gitignore real |
| `prune: true` on platform objects | Deletes platform objects | Use model-appropriate prune |
| Hardcoding `${VAR}` without declaring | `validate-overlay.sh` catches this | Declare every `${VAR}` |
| Copying entire resources instead of patching | Duplicates base | Use JSON patches |
| ConfigMap after AppDeployment | Kommander retries until CM exists | List ConfigMap first |
| Using `op: replace` on `metadata.name` | Names are stable in base | Only patch `spec` fields |
| Applying NKPCluster to managed cluster | Wrong target — apply to mgmt cluster | Apply to management cluster |
| Bootstrap via Flux | Bootstrap CRs must be applied manually | Apply bootstrap CRs manually |

---

## 16. Quick Reference Card

```
┌─────────────────────────────────────────────────────────────────┐
│  NKP GitOps Standards — Quick Reference                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  base/management-cluster/          → self-managed cluster        │
│  base/managed-clusters/<name>/     → workload clusters           │
│  base/appdeployments/<app>/        → NKP ClusterApps             │
│  base/helm-releases/<app>/         → third-party Helm charts     │
│  base/custom-crds/<app>/           → platform config CRDs        │
│                                                                 │
│  overlay/clusters/<cluster>/       → per-cluster overrides       │
│  ├── bootstrap/                   → Flux bootstrap CRs           │
│  ├── mgmt/                        → mgmt cluster Day-2 apps      │
│  └── managed-<name>/              → workload cluster Day-2 apps  │
│                                                                 │
│  Routing:                                                       │
│    mgmt/ → namespace: kommander, clusterSelector: mgmt-name     │
│    managed-<name>/ → namespace: kommander-default-workspace     │
│                                                                 │
│  Provider Switch:                                               │
│    components: [providers/ad]  →  components: [providers/okta]  │
│                                                                 │
│  Version Management:                                            │
│    base/versions/app-versions.configmap.yaml                    │
│    → kustomize replacements → AppDeployment spec.appRef.name   │
│                                                                 │
│  Variable Flow:                                                 │
│    base: ${VAR}  →  cluster-vars.yaml  →  Flux                  │
│    base: ${VAR}  →  .env (local)  →  render.sh                  │
│                                                                 │
│  Prune Policy:                                                  │
│    App resources:  prune: true  (safe to recreate)              │
│    Platform objects: prune: false (never auto-delete)           │
│                                                                 │
│  Validation:                                                    │
│    scripts/validate-overlay.sh <cluster>   # undeclared ${VAR}  │
│    scripts/render.sh <cluster>             # local envsubst     │
│    scripts/verify-prune.sh <cluster>       # prune compliance   │
│    kubectl apply -k overlay/clusters/<c>/mgmt  # deploy mgmt    │
│    kubectl apply -k overlay/clusters/<c>/managed-<n> # deploy   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

*This document is the standalone reference. For complete technical details, see [ntnx-nkp-tpl-gitops.md](ntnx-nkp-tpl-gitops.md).*
