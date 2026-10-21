# PRACTICES — NKP Application Manifest Standards

> **Read this first.** This document is the standalone reference for configuring NKP applications
> using Kustomize + Flux GitOps. It covers all three deployment models.
>
> For the complete technical reference (800+ lines with agentic instructions), see
> [ntnx-nkp-tpl-repo.md](ntnx-nkp-tpl-repo.md).

---

## 1. Core Principles

| Principle | Rule | Why |
|---|---|---|
| **Separation of concerns** | `base/` = generic templates. `overlay/` = per-cluster overrides. Never edit `base/` for a cluster. | Reusability, no merge conflicts |
| **Placeholders, not values** | `base/` uses `${VAR}` for everything that differs per cluster. Overlay provides concrete values. | One template, many clusters |
| **Components, not resources** | Overlay patches use `kind: Component` with `components:` in the aggregator. | Swappability, clean hierarchy |
| **JSON patches, not declarations** | Override fields with RFC 6902 JSON patches (`op: replace`). Don't re-declare whole resources. | Minimal diffs, easy review |
| **Secrets out of git** | Real secrets are gitignored. `*.example` templates are committed. | Security, auditability |
| **Prune by risk** | App resources: `prune: true`. Platform objects (License, Connector): `prune: false`. | Prevent accidental deletion |

---

## 2. Directory Structure

Every repo MUST follow this structure:

```
<repo>/
├── PRACTICES.md                     # ← You are here
├── ntnx-nkp-tpl-repo.md             # Complete technical reference
├── CHANGELOG.md                     # Version history
├── .gitignore
│
├── base/                            # GENERIC templates (immutable)
│   ├── versions/
│   │   └── app-versions.configmap.yaml   # Centralized version registry
│   ├── appdeployments/              # Model 1: Kommander AppDeployments
│   │   └── <app>/
│   │       ├── kustomization.yaml
│   │       ├── <app>.appdeployment.yaml
│   │       └── configs/
│   │           └── <app>-override.yaml
│   ├── helm-releases/               # Model 2: Flux HelmReleases
│   │   └── <app>/
│   │       ├── kustomization.yaml
│   │       ├── helmrepository.yaml
│   │       └── helmrelease.yaml
│   ├── custom-crds/                 # Model 3: Custom CRDs (Dex, MetalLB, etc.)
│   │   └── <app>/
│   │       ├── kustomization.yaml
│   │       ├── <resource>.yaml
│   │       └── providers/           # Optional: swappable implementations
│   │           └── <provider>/
│   │               ├── kustomization.yaml
│   │               └── <resource>.yaml
│   └── README.md
│
├── overlay/                         # PER-CLUSTER overrides
│   └── clusters/
│       └── reference/               # 🔑 REFERENCE cluster — copy for real clusters
│           ├── cluster-vars.yaml    # ConfigMap: non-secret ${VAR} values
│           ├── .env.example         # .env template for local renders
│           ├── cluster-apps/
│           │   ├── kustomization.yaml   # aggregator
│           │   └── patches/
│           │       ├── appdeployments/<app>/
│           │       ├── helm-releases/<app>/
│           │       └── custom-crds/<app>/
│           └── flux-system/
│               ├── gitrepository.yaml
│               └── 01-cluster-apps.yaml
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

1. **One directory per app** under `base/<model>/<app>/`.
2. **Each directory has its own `kustomization.yaml`**.
3. **Providers go under `providers/`** only when you need swappable implementations.
4. **`overlay/clusters/reference/` is required** — no real cluster overlay exists until copied.
5. **`flux-system/` is required** in every cluster overlay.

---

## 3. Choosing a Deployment Model

| Use this model when... | Example apps |
|---|---|
| **AppDeployment** (`apps.kommander.d2iq.io/v1alpha3`) | Deploying an NKP ClusterApp from the Kommander catalog (monitoring, logging, storage, backup) |
| **HelmRelease** (`helm.toolkit.fluxcd.io/v2`) | Deploying a third-party Helm chart not in the NKP catalog (Vault, custom charts, operators) |
| **Custom CRD** | Configuring platform objects that are CRs but not AppDeployments (Dex Connectors, VirtualGroups, MetalLB, License) |

### Decision Flow

```
Is the app an NKP ClusterApp (from the Kommander catalog)?
  → YES → Use AppDeployment
  → NO  → Is it a Helm chart (from a HelmRepository)?
    → YES → Use HelmRelease
    → NO  → Is it a custom CR (Connector, VirtualGroup, etc.)?
      → YES → Use Custom CRD
```

---

## 4. Base Layer Standards (All Models)

### 4.1 Variable Naming

- **Format:** `UPPERCASE_WITH_UNDERSCORES`
- **Prefix:** `<APP>_<FIELD>` or `<CATEGORY>_<FIELD>`
- **Examples:** `FLUENT_BIT_IMAGE_TAG`, `VAULT_ADDR`, `DEX_LDAP_HOST`

### 4.2 Variable Declaration

| Type | Where declared | Example |
|---|---|---|
| Non-secret | `overlay/clusters/<cluster>/cluster-vars.yaml` (ConfigMap) | `FLUENT_BIT_IMAGE_TAG: "0.57.2"` |
| Secret | `overlay/clusters/<cluster>/cluster-secrets` (Secret) | `FLUENT_BIT_API_KEY: "${FLUENT_BIT_API_KEY}"` |
| Both | `overlay/clusters/<cluster>/.env.example` | `FLUENT_BIT_IMAGE_TAG="0.57.2"` |

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
- Be placed in `base/<model>/<app>/` or a subdirectory

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

## 5. Model 1: AppDeployment Standards

### 5.1 Directory Structure

```
base/appdeployments/<app>/
├── kustomization.yaml
├── <app>.appdeployment.yaml
└── configs/
    └── <app>-override.yaml      # Helm values ConfigMap
```

### 5.2 AppDeployment Template

```yaml
# base/appdeployments/<app>/<app>.appdeployment.yaml
apiVersion: apps.kommander.d2iq.io/v1alpha3
kind: AppDeployment
metadata:
  name: <app>
  namespace: kommander
spec:
  appRef:
    appID: <catalog-app-id>
    kind: ClusterApp
    name: "${<APP>_APP_REF}"          # Version from centralized versions ConfigMap
    namespace: kommander
  configOverrides:
    name: "<app>-override"            # ConfigMap with Helm values
  clusterConfigOverrides:             # Route to specific clusters
    - clusterSelector:
        matchExpressions:
          - key: kommander.d2iq.io/cluster-name
            operator: In
            values: ["mgmt-a"]
      configMapName: "<app>-override"
```

### 5.3 Override ConfigMap

```yaml
# base/appdeployments/<app>/configs/<app>-override.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <app>-override
  namespace: kommander
data:
  values.yaml: |
    # Helm values with ${VAR} placeholders
    image:
      tag: "${<APP>_IMAGE_TAG}"
    someSetting: "${<APP>_SOME_SETTING}"
```

### 5.4 Version Management

Versions are centralized in `base/versions/app-versions.configmap.yaml`:

```yaml
# base/versions/app-versions.configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-versions
  namespace: kommander
data:
  fluent-bit: "fluent-bit-0.57.2"
  kube-prometheus-stack: "kube-prometheus-stack-82.13.6"
  rook-ceph-cluster: "rook-ceph-cluster-1.19.6"
```

The overlay's `kustomization.yaml` uses `replacements` to inject versions:

```yaml
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

### 5.5 Cluster Routing

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

### 5.6 Overlay Patch

```yaml
# overlay/.../patches/appdeployments/<app>/connector.yaml
- op: replace
  path: /spec/appRef/name
  value: "${<APP>_APP_REF}"           # Flux substitutes from cluster-vars

- op: replace
  path: /spec/clusterConfigOverrides/0/clusterSelector/matchExpressions/0/values/0
  value: "${<CLUSTER_NAME}"           # Per-cluster cluster name
```

---

## 6. Model 2: HelmRelease Standards

### 6.1 Directory Structure

```
base/helm-releases/<app>/
├── kustomization.yaml
├── helmrepository.yaml
└── helmrelease.yaml
```

### 6.2 HelmRepository Template

```yaml
# base/helm-releases/<app>/helmrepository.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: <app>
  namespace: <namespace>
spec:
  type: oci
  interval: 5m
  url: "${<APP>_HELM_REPO_URL}"       # e.g., oci://ghcr.io/bank-vaults/helm-charts
```

### 6.3 HelmRelease Template

```yaml
# base/helm-releases/<app>/helmrelease.yaml
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
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
  values:
    someSetting: "${<APP>_SOME_SETTING}"
    image:
      tag: "${<APP>_IMAGE_TAG}"
```

### 6.4 Overlay Patch

```yaml
# overlay/.../patches/helm-releases/<app>/values-patch.yaml
- op: replace
  path: /spec/chart/spec/version
  value: "${<APP>_CHART_VERSION}"

- op: replace
  path: /spec/values/someSetting
  value: "${<APP>_SOME_SETTING}"
```

### 6.5 Prune Policy

**App resources:** `prune: true` (Flux can safely delete and recreate HelmReleases)

```yaml
# flux-system/01-cluster-apps.yaml
spec:
  prune: true                          # Safe for HelmRelease-managed resources
```

---

## 7. Model 3: Custom CRD Standards

### 7.1 Directory Structure

```
base/custom-crds/<app>/
├── kustomization.yaml
├── <resource>.yaml
└── providers/                          # Optional
    └── <provider>/
        ├── kustomization.yaml
        └── <resource>.yaml
```

### 7.2 Resource Template

```yaml
# base/custom-crds/<app>/<resource>.yaml
apiVersion: <api-group>/<version>
kind: <Kind>
metadata:
  name: <stable-name>
  namespace: kommander
spec:
  field: "${<APP>_FIELD}"
```

### 7.3 Provider Switching

When you need swappable implementations:

```yaml
# overlay/.../patches/custom-crds/<app>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
resources:
  - ../../../../../../../base/custom-crds/<app>
components:
  - providers/<default-provider>    # ← switch to providers/<other>
```

Switch providers by changing one line:
```yaml
components:
  - providers/ad       # ← default
  # OR
  - providers/okta     # ← switch
```

### 7.4 Prune Policy

**Platform objects:** `prune: false` (never cascade-delete platform config)

```yaml
# flux-system/01-cluster-apps.yaml
spec:
  prune: false                         # Platform objects — never auto-delete
```

---

## 8. Overlay Standards (All Models)

### 8.1 Aggregator

```yaml
# overlay/clusters/<cluster>/cluster-apps/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
components:
  - patches/appdeployments/<app>
  - patches/helm-releases/<app>
  - patches/custom-crds/<app>
```

### 8.2 Component

```yaml
# overlay/.../patches/<model>/<app>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
resources:
  - ../../../../../../../base/<model>/<app>
patches:
  - path: patch.yaml
    target: { group: <api-group>, version: <version>, kind: <Kind>, name: <name> }
```

### 8.3 JSON Patches

```yaml
# overlay/.../patches/<model>/<app>/patch.yaml
- op: replace
  path: /spec/<field>
  value: "${<APP>_FIELD}"       # Flux substitutes from cluster-vars

- op: add
  path: /spec/<newField>
  value: "new-value"
```

**Rules:**
- Target by `group/version/kind/name` — never by index
- Use `${VAR}` for Flux-substituted values
- Commit concrete values ONLY for `reference` cluster
- Keep patches minimal — only override what differs

### 8.4 Secret Patches

```yaml
# overlay/.../secret-patch.yaml.example
- op: replace
  path: /stringData/<key>
  value: "${<APP>_SECRET_VAR}"
```

- Commit as `*.example`
- Gitignore the real file
- Reference `${VAR}` so Flux substitutes from `cluster-secrets`

---

## 9. Flux Best Practices

### 9.1 Prune Policy

| Resource Type | Prune | Reason |
|---|---|---|
| AppDeployment apps | `true` | Safe to recreate |
| HelmRelease apps | `true` | Safe to recreate |
| License CR | `false` | Platform object — deleting breaks Kommander |
| Connector CR | `false` | Platform object — deleting breaks identity |
| VirtualGroup / RBAC | `false` | Platform object — deleting breaks access |
| Custom platform CRs | `false` | Platform object |
| App-specific Secrets | `true` | App resource |
| Platform Secrets | `false` | Platform resource |

### 9.2 postBuild Substitution

```yaml
# flux-system/01-cluster-apps.yaml
spec:
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-vars
      - kind: Secret
        name: cluster-secrets
        optional: true
```

### 9.3 Resource Ordering

ConfigMaps MUST be listed before AppDeployments that reference them:

```yaml
# base/appdeployments/<app>/kustomization.yaml
resources:
  - configs/<app>-override.yaml    # ← ConfigMap first
  - <app>.appdeployment.yaml       # ← AppDeployment second
```

Kommander retries until the ConfigMap exists, but explicit ordering is clearer.

### 9.4 GitRepository

```yaml
# flux-system/gitrepository.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: <repo-name>
  namespace: kommander-flux
spec:
  interval: 1m
  url: https://github.com/<org>/<repo>.git
  ref:
    branch: main
  provider: github
  secretRef:
    name: github-app-auth
```

---

## 10. Secret Management

### 10.1 Rules

- **NEVER** commit real secrets
- **ALWAYS** commit `*.example` templates
- Use `stringData` (not `secretGenerator`) so `${VAR}` stays visible to Flux
- Gitignore: `secret-patch.yaml`, `secret.yaml`, `.env`, `*.secret.yaml`
- Commit: `secret-patch.yaml.example`, `secret.yaml.example`, `.env.example`

### 10.2 Delivery Paths

| Path | How it works |
|---|---|
| **Flux postBuild** | `${VAR}` in `secret-patch.yaml` → substituted from `cluster-secrets` Secret |
| **ESO (External Secrets)** | Secret managed from Vault/KV store (manual `kubectl apply` reverted) |
| **Manual apply** | `kubectl apply` with local `.env` (testing only) |

### 10.3 Secret Key Conventions

| Secret Type | Keys |
|---|---|
| LDAP bind | `password` |
| OIDC client | `client-id`, `client-secret` |
| GitHub client | `client-id`, `client-secret` |
| CA certificate | `tls.crt` |
| Generic API key | `api-key` or `token` |

---

## 11. Validation Checklist

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

## 12. Anti-Patterns

| Anti-Pattern | Why It's Wrong | Correct Approach |
|---|---|---|
| Concrete values in `base/` | Breaks reusability | Use `${VAR}`, set in overlay |
| `secretGenerator` | Base64-encodes values, hiding `${VAR}` | Use `stringData` |
| Editing `base/` for a cluster | Causes merge conflicts | Create overlay patches |
| `resources:` for overlay patches | Mixes patches with base | Use `components:` |
| `v1alpha1` in base Kustomizations | Wrong API version | Use `v1beta1` in base, `v1alpha1` only for Components |
| Committing real secrets | Security risk | Commit `*.example`, gitignore real |
| `prune: false` on app resources | Wastes resources, but also `prune: true` on platform objects deletes them | Model-appropriate prune |
| Hardcoding `${VAR}` without declaring | `validate-overlay.sh` catches this | Declare every `${VAR}` in `cluster-vars.yaml` or `.env` |
| Copying entire resources instead of patching | Duplicates base | Use JSON patches |
| ConfigMap after AppDeployment | Kommander retries until CM exists | List ConfigMap first in resources |
| Using `op: replace` on `metadata.name` | Names are stable in base | Only patch `spec` fields |

---

## 13. Quick Reference Card

```
┌─────────────────────────────────────────────────────────────────┐
│  NKP Manifest Standards — Quick Reference                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  base/<model>/<app>/                → generic templates         │
│  overlay/clusters/<cluster>/        → per-cluster overrides     │
│  flux-system/                       → Flux GitOps CRs           │
│                                                                 │
│  Models:                                                        │
│    appdeployments/  → Kommander ClusterApps (AppDeployment CR)  │
│    helm-releases/   → Third-party Helm charts (HelmRelease CR)  │
│    custom-crds/     → Platform config (Connector, VG, etc.)     │
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
│    kubectl apply -k overlay/clusters/<c>/cluster-apps  # deploy │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

*This document is the standalone reference. For complete technical details, see [ntnx-nkp-tpl-repo.md](ntnx-nkp-tpl-repo.md).*
