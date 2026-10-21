# ntnx-nkp-tpl-gitops

**Kustomize + Flux GitOps template for NKP/Kommander.**

A production-ready reference for organizing Kubernetes manifests with Kustomize, Flux GitOps,
and five resource categories — modeled after real NKP production repos (`nkp-infra-tf-src`,
`ntnx-nkp-dex`, `ntnx-iac-live-nkp-platform`).

---

## What's Inside

| Path | Purpose |
|---|---|
| [`PRACTICES.md`](PRACTICES.md) | **Standalone reference** — rules, standards, model selection guide |
| [`ntnx-nkp-tpl-gitops.md`](ntnx-nkp-tpl-gitops.md) | Complete technical reference (800+ lines) with agentic instructions |
| `base/management-cluster/` | Self-managed cluster (NKPCluster mode: management) |
| `base/managed-clusters/` | Workload clusters (NKPCluster mode: managed) |
| `base/appdeployments/` | NKP ClusterApps (worked example: `fluent-bit`) |
| `base/helm-releases/` | Third-party Helm charts (worked example: `vault-operator`) |
| `base/custom-crds/` | Custom CRDs (worked example: Dex identity access) |
| `base/versions/` | Centralized version registry with kustomize replacements |
| `overlay/clusters/reference/` | Reference cluster overlay — copy for real clusters |
| `scripts/` | `validate-overlay.sh`, `render.sh`, `verify-prune.sh` |
| `docs/adr/` | Architecture Decision Records |
| `docs/guides/` | Deployment-specific guides |
| `troubleshooting/` | Symptom → cause → fix runbooks |

---

## Five Resource Categories

| Category | Purpose | Example |
|---|---|---|
| **Management Cluster** | Self-managed NKP cluster (kind → pivot → Kommander) | First cluster in the environment |
| **Managed Clusters** | Workload clusters managed by the management cluster | Additional clusters for workloads |
| **AppDeployments** | NKP ClusterApps (monitoring, logging, storage, backup) | `fluent-bit`, `kube-prometheus-stack`, `velero` |
| **HelmReleases** | Third-party Helm charts (operators, custom apps) | `vault-operator`, `ingress-nginx` |
| **Custom CRDs** | Platform config (Dex Connectors, MetalLB, VirtualGroups) | Identity, networking, license |

See [PRACTICES.md](PRACTICES.md) Section 3 for the decision flow.

---

## Quickstart

```bash
# Validate the reference overlay renders (no undeclared ${VAR})
scripts/validate-overlay.sh reference

# Local render of a cluster (${VAR} from the cluster's .env)
scripts/render.sh reference

# Verify prune policies are correct
scripts/verify-prune.sh reference

# Apply to a cluster
kubectl apply -k overlay/clusters/<cluster>/mgmt          # management cluster
kubectl apply -k overlay/clusters/<cluster>/managed-<name> # workload cluster
```

---

## Architecture

```
base/                              ← generic templates (no cluster-specific values)
├── versions/                      ← centralized version registry
├── management-cluster/            ← NKPCluster (mode: management)
├── managed-clusters/<cluster>/    ← NKPCluster (mode: managed)
├── appdeployments/<app>/          ← AppDeployment CR + ConfigMap
├── helm-releases/<app>/           ← HelmRepository + HelmRelease CR
└── custom-crds/<app>/             ← Custom CRD (+ optional providers/)

overlay/clusters/<cluster>/        ← per-cluster overrides
├── cluster-vars.yaml              ← non-secret ${VAR} values (ConfigMap)
├── .env.example                   ← .env template for local renders
├── bootstrap/                     ← Flux bootstrap CRs (applied manually)
├── mgmt/                          ← management cluster Day-2 apps
└── managed-<name>/                ← workload cluster Day-2 apps

scripts/
├── validate-overlay.sh            ← build + undeclared ${VAR} check
├── render.sh                      ← local envsubst rendering
└── verify-prune.sh                ← prune policy compliance check
```

---

## Key Concepts

### Base-Overlay Separation

- **`base/`** = generic, reusable templates. No IPs, DNs, passwords, or hostnames.
- **`overlay/`** = per-cluster overrides. Never edit `base/` for a cluster.

### Multi-Cluster Routing

- `mgmt/` → namespace: `kommander`, clusterSelector: `${MGMT_CLUSTER_NAME}`
- `managed-<name>/` → namespace: `kommander-default-workspace`, clusterSelector: `${WORKLOAD_CLUSTER_NAME}`

### Version Management

Versions are centralized in `base/versions/app-versions.configmap.yaml` and injected into
AppDeployments via kustomize `replacements`. Update a single line to upgrade an app.

### Provider Switching (Custom CRDs)

Switch identity providers by changing one line:
```yaml
components:
  - providers/ad    # ← AD/LDAP (default)
  # OR
  - providers/okta  # ← Okta/OIDC
```

### Variable Substitution

- Templates use `${VAR}` placeholders.
- `cluster-vars.yaml` (ConfigMap) holds non-secret values for Flux.
- `.env` (gitignored) holds values for local rendering.
- `scripts/render.sh` mirrors Flux `postBuild` locally.

### Secret Management

- Secrets use `stringData` (not `secretGenerator`).
- Real secret files are **gitignored**.
- `*.example` templates are **committed** — copy and fill before applying.

### Prune Policy

- **App resources:** `prune: true` (safe to recreate)
- **Platform objects:** `prune: false` (never auto-delete)

---

## Creating a Real Cluster

```bash
# 1. Copy the reference
cp -r overlay/clusters/reference overlay/clusters/<your-cluster>

# 2. Fill in values
#    - Edit cluster-vars.yaml with real ${VAR} values
#    - Copy .env.example → .env and fill in real values
#    - Copy secret-patch.yaml.example → secret-patch.yaml (gitignored)

# 3. Validate
scripts/validate-overlay.sh <your-cluster>

# 4. Render (optional, to inspect)
scripts/render.sh <your-cluster>

# 5. Apply
kubectl apply -k overlay/clusters/<your-cluster>/mgmt          # mgmt cluster
kubectl apply -k overlay/clusters/<your-cluster>/managed-<n>   # workload cluster
```

---

## Documentation

- **[PRACTICES.md](PRACTICES.md)** — Standalone rules and standards (read this first)
- [Complete Reference](ntnx-nkp-tpl-gitops.md) — All rules, standards, and agentic instructions
- [ADR Index](docs/adr/README.md) — Architecture decisions
- [Overlay Model Spec](docs/specs/overlay-model.md) — How base → cluster works
- [Version Management Spec](docs/specs/version-management.md) — Centralized versions
- [Troubleshooting](troubleshooting/README.md) — Common issues and fixes

---

## Validation

Before committing any change:

```bash
scripts/validate-overlay.sh reference   # check undeclared ${VAR}
scripts/render.sh reference             # local envsubst test
scripts/verify-prune.sh reference       # prune policy compliance
```

---

## Anti-Patterns

| Anti-Pattern | Correct Approach |
|---|---|
| Concrete values in `base/` | Use `${VAR}`, set in overlay |
| `secretGenerator` | Use `stringData` |
| Editing `base/` for a cluster | Create overlay patches |
| `resources:` for overlay patches | Use `components:` |
| `v1alpha1` in base Kustomizations | Use `v1beta1` in base |
| Committing real secrets | Commit `*.example`, gitignore real |
| `prune: true` on platform objects | Use model-appropriate prune |
| ConfigMap after AppDeployment | List ConfigMap first in resources |
| Applying NKPCluster to managed cluster | Apply to management cluster |
| Bootstrap via Flux | Apply bootstrap CRs manually |

---

*This is a template repository. Use it as the foundation for your own NKP GitOps repositories.
Start with [PRACTICES.md](PRACTICES.md) for the rules, then follow the guides in `docs/guides/`.*
