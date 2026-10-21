# Project Context — ntnx-nkp-tpl-gitops

> **Auto-loaded in every session.** This file provides complete project context so agents
> don't need to re-explore the codebase.

---

## 1. Project Identity

- **Name:** ntnx-nkp-tpl-gitops
- **Purpose:** Kustomize + Flux GitOps template for NKP/Kommander
- **URL:** https://github.com/fernandoquinino-ntx/ntnx-nkp-tpl-gitops
- **Tag:** v3.0.0
- **Based on:** ntnx-nkp-dex, nkp-infra-tf-src, ntx-iac-live-nkp-platform

## 2. Directory Structure

```
ntnx-nkp-tpl-gitops/
├── .agents/                     # Agent definitions (this directory)
├── .github/workflows/           # CI/CD
├── base/                        # GENERIC templates (immutable, ${VAR} only)
│   ├── versions/
│   │   └── app-versions.configmap.yaml   # Centralized version registry
│   ├── management-cluster/      # Self-managed cluster (NKPCluster mode: management)
│   │   ├── kustomization.yaml
│   │   ├── nkpcluster.yaml              # WITH kommander.d2iq.io/host: "true"
│   │   ├── secrets.yaml                 # 5 secrets
│   │   ├── kommander-bootstrap-config.yaml
│   │   ├── kommander-installer-config.yaml
│   │   └── dockerhub-auth.yaml
│   ├── managed-clusters/            # Workload clusters (NKPCluster mode: managed)
│   │   └── <cluster>/
│   │       ├── kustomization.yaml
│   │       ├── nkpcluster.yaml      # WITHOUT host label
│   │       └── secrets.yaml         # 3 secrets only
│   ├── appdeployments/              # Day-2: NKP ClusterApps
│   │   └── fluent-bit/
│   │       ├── kustomization.yaml
│   │       ├── fluent-bit.appdeployment.yaml
│   │       └── configs/fluent-bit-override.yaml
│   ├── helm-releases/               # Day-2: Third-party Helm charts
│   │   └── vault-operator/
│   │       ├── kustomization.yaml
│   │       ├── helmrepository.yaml
│   │       └── helmrelease.yaml
│   ├── custom-crds/                 # Day-2: Custom CRDs
│   │   └── identity-access/dex/
│   │       ├── kustomization.yaml
│   │       ├── virtual-group.yaml
│   │       ├── clusterrolebinding.yaml
│   │       ├── connectors/{ad,okta}/
│   │       └── secrets/{ldap-bind,okta-client}/
│   └── README.md
├── overlay/                         # PER-CLUSTER overrides
│   └── clusters/
│       └── reference/               # 🔑 REFERENCE — copy for real clusters
│           ├── cluster-vars.yaml    # ConfigMap: non-secret ${VAR} values
│           ├── .env.example         # .env template for local renders
│           ├── bootstrap/           # Flux bootstrap CRs (applied manually)
│           │   ├── gitrepository.yaml
│           │   ├── root-kustomization.yaml       # → mgmt/ on mgmt cluster
│           │   └── managed-01-kustomization.yaml # → managed-01/ on managed
│           ├── mgmt/                # Management cluster Day-2 apps
│           │   ├── kustomization.yaml
│           │   └── patches/<model>/<app>/
│           └── managed-01/          # Workload cluster Day-2 apps
│               ├── kustomization.yaml
│               └── patches/<model>/<app>/
├── scripts/
│   ├── validate-overlay.sh          # kustomize build + undeclared ${VAR}
│   ├── render.sh                    # local envsubst rendering
│   └── verify-prune.sh              # prune policy compliance
├── docs/
│   ├── adr/ (8 ADRs)
│   ├── guides/ (7 guides)
│   └── specs/ (3 specs)
├── troubleshooting/ (6 runbooks)
├── PRACTICES.md                     # STANDALONE reference
├── ntnx-nkp-tpl-gitops.md           # Complete technical reference
├── README.md
├── CHANGELOG.md
└── .gitignore
```

## 3. Five Resource Categories

### Category 1: Management Cluster
- **Directory:** `base/management-cluster/`
- **CRD:** NKPCluster (mode: management)
- **Label:** `kommander.d2iq.io/host: "true"`
- **Secrets:** 5 + metadata ConfigMap
- **Deployed to:** kind bootstrap → pivot → self-managed
- **Use when:** First cluster in the environment

### Category 2: Managed Clusters
- **Directory:** `base/managed-clusters/<cluster>/`
- **CRD:** NKPCluster (mode: managed)
- **Label:** None (no host label)
- **Secrets:** 3 only
- **Deployed to:** Management cluster's workspace namespace
- **Use when:** Additional workload clusters

### Category 3: AppDeployments
- **Directory:** `base/appdeployments/<app>/`
- **CRD:** `apps.kommander.d2iq.io/v1alpha3`
- **Use when:** NKP ClusterApp from Kommander catalog
- **Example:** fluent-bit, kube-prometheus-stack, velero

### Category 4: HelmReleases
- **Directory:** `base/helm-releases/<app>/`
- **CRD:** `helm.toolkit.fluxcd.io/v2`
- **Use when:** Third-party Helm chart via Flux
- **Example:** vault-operator, ingress-nginx

### Category 5: Custom CRDs
- **Directory:** `base/custom-crds/<app>/`
- **CRD:** Various (Dex, Kommander, etc.)
- **Use when:** Platform config CRs not AppDeployment/HelmRelease
- **Example:** Dex Connectors, VirtualGroups, MetalLB

## 4. Multi-Cluster Routing

| Directory | Namespace | clusterSelector | Flux Kustomization |
|---|---|---|---|
| `mgmt/` | `kommander` | `${MGMT_CLUSTER_NAME}` | `root-kustomization.yaml` |
| `managed-<name>/` | `kommander-default-workspace` | `${WORKLOAD_CLUSTER_NAME}` | `<name>-kustomization.yaml` |

## 5. Key Patterns

### Base-Overlay Separation
- `base/` = generic, `${VAR}` placeholders only
- `overlay/` = per-cluster overrides via Components + JSON patches
- Never edit `base/` for a cluster

### Provider Switching (Custom CRDs)
```yaml
components:
  - providers/ad    # ← AD/LDAP (default)
  # OR
  - providers/okta  # ← Okta/OIDC
```

### Version Management
- Centralized: `base/versions/app-versions.configmap.yaml`
- Injected via kustomize `replacements` in overlay
- Update one line to upgrade an app

### Secret Management
- `stringData` (not `secretGenerator`)
- Real files gitignored: `secret-patch.yaml`, `secret.yaml`, `.env`
- Templates committed: `*.example`
- Flux substitutes from `cluster-secrets` Secret

### Prune Policy
- App resources: `prune: true` (safe to recreate)
- Platform objects: `prune: false` (never auto-delete)
- NKPCluster, License, Connector: `prune: false`

### Flux Bootstrap
- CRs in `overlay/.../bootstrap/` applied MANUALLY (not via Flux)
- Solves chicken-and-egg: repo Flux reads from is itself in the repo

## 6. Variable Conventions

- **Format:** `UPPERCASE_WITH_UNDERSCORES`
- **Prefix:** `<CATEGORY>_<FIELD>`
- **Non-secret:** `cluster-vars.yaml` (ConfigMap)
- **Secret:** `cluster-secrets` (Secret)
- **Both:** `.env.example`

### Common Variables

| Variable | Category | Example |
|---|---|---|
| `MGMT_CLUSTER_NAME` | Management | `mgmt-a` |
| `MANAGED_CLUSTER_NAME` | Managed | `managed-01` |
| `MANAGED_CLUSTER_NAMESPACE` | Managed | `kommander-default-workspace` |
| `PRISM_ENDPOINT` | Cluster | `10.0.0.100` |
| `PRISM_USERNAME` / `PRISM_PASSWORD` | Cluster | `admin@local` / ... |
| `CONTROL_PLANE_VIP` | Cluster | `10.0.0.200` |
| `NKP_IMAGE_NAME` | Cluster | `nkp-rocky-9.7-1.35.2` |
| `KUBERNETES_VERSION` | Cluster | `v1.35.2` |
| `NKP_VERSION` | Cluster | `v2.18.0` |
| `FLUENT_BIT_APP_REF` | AppDeployment | `fluent-bit-0.57.2` |
| `VAULT_OPERATOR_CHART_VERSION` | HelmRelease | `1.24.1` |
| `DEX_LDAP_HOST` | Custom CRD | `dc01.ad.example.local:636` |

## 7. Validation Commands

```bash
scripts/validate-overlay.sh reference   # undeclared ${VAR} check
scripts/render.sh reference             # local envsubst test
scripts/verify-prune.sh reference       # prune policy compliance
kustomize build -k overlay/clusters/reference/mgmt
kustomize build -k overlay/clusters/reference/managed-01
```

## 8. Key Files

| File | Purpose |
|---|---|
| `PRACTICES.md` | Standalone rules reference (read first) |
| `ntnx-nkp-tpl-gitops.md` | Complete technical reference (800+ lines) |
| `base/versions/app-versions.configmap.yaml` | Centralized versions |
| `overlay/clusters/reference/cluster-vars.yaml` | Non-secret ${VAR} values |
| `overlay/clusters/reference/.env.example` | Local render template |
| `overlay/.../bootstrap/*.yaml` | Flux bootstrap CRs |

## 9. Anti-Patterns to Avoid

| Anti-Pattern | Correct Approach |
|---|---|
| Concrete values in `base/` | Use `${VAR}`, set in overlay |
| `secretGenerator` | Use `stringData` |
| Editing `base/` for a cluster | Create overlay patches |
| `resources:` for overlay patches | Use `components:` |
| `v1alpha1` in base Kustomizations | Use `v1beta1` in base |
| Committing real secrets | Commit `*.example`, gitignore real |
| `prune: true` on platform objects | Use model-appropriate prune |
| ConfigMap after AppDeployment | List ConfigMap first |
| Applying NKPCluster to managed cluster | Apply to management cluster |
| Bootstrap via Flux | Apply bootstrap CRs manually |

## 10. Deployment Sequence

### Management Cluster
1. `nkp create bootstrap` → kind cluster
2. Apply `base/management-cluster/` → kind cluster
3. Wait for Provisioned
4. `nkp get kubeconfig` → workload kubeconfig
5. `nkp create capi-components` → workload
6. `nkp move capi-resources` → pivot
7. `nkp delete bootstrap`
8. `nkp install kommander`
9. Apply `overlay/.../mgmt/` → Flux syncs Day-2 apps

### Managed Cluster
1. Apply `base/managed-clusters/<name>/` → MANAGEMENT cluster
2. Wait for Provisioned
3. Extract kubeconfig from `{name}-kubeconfig` Secret
4. Apply `overlay/.../managed-<name>/` → Flux syncs Day-2 apps

