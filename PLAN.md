# Plan — ntnx-nkp-tpl-gitops v2: Generic Kustomize + Flux Template for NKP Apps

## Problem Statement

The current `ntnx-nkp-tpl-gitops` is too Dex-specific. It uses Dex terminology, Dex CRDs, and Dex directory names throughout. What's needed is a **generic, production-ready template** that any Kubernetes engineer or DevOps engineer can follow to configure **any** NKP application — whether it's an AppDeployment, HelmRelease, plain Kustomization, or custom CR — using the same base-overlay pattern.

## What We Actually Have (Real NKP Patterns)

From analyzing the production repos (`nkp-infra-tf-src`, `nkp-infra-tf`, `ntnx-nkp-dex`), there are **three deployment models** in use:

| Model | CRD | Use Case | Repo Pattern |
|---|---|---|---|
| **AppDeployment** | `apps.kommander.d2iq.io/v1alpha3` | NKP ClusterApps (monitoring, logging, storage, backup) | `nkp-infra-tf-src` (kustomize overlays + replacements for versions) |
| **HelmRelease** | `helm.toolkit.fluxcd.io/v2` | Third-party Helm charts (Vault operator, custom charts) | Inline manifests in cluster overlays |
| **Connector/Custom CR** | `dex.mesosphere.io/v1alpha1`, etc. | NKP platform config (identity, networking) | `ntnx-nkp-dex` (kustomize Components with provider switching) |

All three share the same **organizational pattern**:
- `base/` = generic templates with `${VAR}` placeholders
- `overlay/clusters/<cluster>/` = per-cluster overrides
- `flux-system/` = Flux GitOps CRs

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Template approach** | Generic skeleton + 3 worked examples | Don't force one model; show all three |
| **App categories** | By deployment model, not by domain | `appdeployments/`, `helm-releases/`, `custom-crds/` — not `identity/`, `monitoring/` |
| **Version management** | Centralized ConfigMap + kustomize replacements | Matches `nkp-infra-tf-src` production pattern |
| **Cluster routing** | `clusterConfigOverrides` for AppDeployments, namespace for HelmReleases | Matches NKP reality |
| **Prune policy** | `prune: true` for app resources, `prune: false` for platform objects | App resources can be safely pruned; platform objects (License, Connector) cannot |
| **Secret handling** | `*.example` + gitignore + Flux `cluster-secrets` | Matches all existing repos |
| **Repo scope** | One repo per application (or app family) | Matches the "dedicated manifest repo per app" requirement |

## Repository Structure

```
ntnx-nkp-tpl-gitops/
├── README.md                          # Overview, quickstart, architecture
├── PRACTICES.md                       # ✅ NEW: Rules, standards, best practices (the "how-to")
├── ntnx-nkp-tpl-gitops.md              # Complete reference (rules + agentic instructions)
├── .gitignore
│
├── base/                              # GENERIC templates (immutable, ${VAR} only)
│   ├── versions/
│   │   └── app-versions.configmap.yaml   # Centralized version registry (kustomize replacements)
│   ├── appdeployments/                # Model 1: Kommander AppDeployments
│   │   ├── <app>/
│   │   │   ├── kustomization.yaml
│   │   │   ├── <app>.appdeployment.yaml   # AppDeployment CR with ${VAR}
│   │   │   └── configs/
│   │   │       └── <app>-override.yaml    # Helm values ConfigMap with ${VAR}
│   │   └── README.md
│   ├── helm-releases/                 # Model 2: Flux HelmReleases
│   │   ├── <app>/
│   │   │   ├── kustomization.yaml
│   │   │   ├── helmrepository.yaml        # Flux HelmRepository CR
│   │   │   ├── helmrelease.yaml           # Flux HelmRelease CR with ${VAR}
│   │   │   └── (optional) patches/        # JSON patches for HelmRelease values
│   │   └── README.md
│   ├── custom-crds/                   # Model 3: Custom CRDs (Dex Connectors, etc.)
│   │   ├── <app>/
│   │   │   ├── kustomization.yaml
│   │   │   ├── <resource>.yaml            # CR with ${VAR}
│   │   │   └── providers/                 # Optional: swappable provider implementations
│   │   │       └── <provider>/
│   │   │           ├── kustomization.yaml
│   │   │           └── <resource>.yaml
│   │   └── README.md
│   └── README.md
│
├── overlay/                           # PER-CLUSTER overrides
│   └── clusters/
│       └── reference/                 # 🔑 REFERENCE cluster
│           ├── cluster-vars.yaml      # ConfigMap: non-secret ${VAR} values
│           ├── .env.example           # .env template for local renders
│           ├── cluster-apps/
│           │   ├── kustomization.yaml # aggregator: components: [patches/*]
│           │   └── patches/
│           │       ├── appdeployments/
│           │       │   └── <app>/
│           │       │       ├── kustomization.yaml   # Component
│           │       │       ├── connector.yaml       # JSON patch for AppDeployment
│           │       │       └── config-patch.yaml    # JSON patch for ConfigMap
│           │       ├── helm-releases/
│           │       │   └── <app>/
│           │       │       ├── kustomization.yaml   # Component
│           │       │       └── values-patch.yaml    # JSON patch for HelmRelease
│           │       └── custom-crds/
│           │           └── <app>/
│           │               ├── kustomization.yaml   # Component
│           │               └── provider/
│           │                   ├── kustomization.yaml
│           │                   ├── patch.yaml
│           │                   └── secret-patch.yaml.example
│           └── flux-system/
│               ├── gitrepository.yaml
│               └── 01-cluster-apps.yaml
│
├── scripts/
│   ├── validate-overlay.sh
│   ├── render.sh
│   └── verify-prune.sh              # ✅ NEW: verify prune policy compliance
│
├── docs/
│   ├── adr/
│   │   ├── README.md
│   │   ├── 0001-three-deployment-models.md
│   │   ├── 0002-version-management.md
│   │   ├── 0003-prune-policy.md
│   │   └── 0004-reference-cluster.md
│   ├── guides/
│   │   ├── getting-started.md
│   │   ├── deploy-appdeployment.md   # ✅ NEW: AppDeployment-specific guide
│   │   ├── deploy-helmrelease.md     # ✅ NEW: HelmRelease-specific guide
│   │   └── deploy-custom-crds.md     # ✅ NEW: Custom CRD guide
│   └── specs/
│       ├── overlay-model.md
│       ├── envsubst-conventions.md
│       └── version-management.md     # ✅ NEW
│
└── troubleshooting/
    ├── README.md
    ├── undeclared-var.md
    ├── component-version.md
    ├── eso-revert.md
    ├── flux-git-sync.md
    ├── prune-policy-violation.md     # ✅ NEW
    └── version-mismatch.md           # ✅ NEW
```

## Actions — Step by Step

### Phase 1: Create the Practices Document (Day 1)
1. Write `PRACTICES.md` — the concise, actionable rules document
   - Section 1: Core Principles (the "why")
   - Section 2: Directory Structure Rules (the "what")
   - Section 3: Deployment Model Selection Guide (which model to use)
   - Section 4: Base Layer Standards (all models)
   - Section 5: AppDeployment Standards (model 1)
   - Section 6: HelmRelease Standards (model 2)
   - Section 7: Custom CRD Standards (model 3)
   - Section 8: Overlay Standards (all models)
   - Section 9: Flux Best Practices (prune, postBuild, ordering)
   - Section 10: Secret Management (all models)
   - Section 11: Version Management (centralized ConfigMap + replacements)
   - Section 12: Cluster Routing (clusterConfigOverrides, selectors)
   - Section 13: Validation Checklist
   - Section 14: Anti-Patterns

### Phase 2: Rewrite the Template Structure (Day 2)
2. Remove Dex-specific names from `base/` — replace with generic examples
3. Create `base/appdeployments/` with a worked example (e.g., `fluent-bit`)
4. Create `base/helm-releases/` with a worked example (e.g., `vault-operator`)
5. Keep `base/custom-crds/` but rename from `identity-access/dex` to `identity-access/dex` with generic labels
6. Create `base/versions/app-versions.configmap.yaml` with example versions
7. Update all overlay files to match the new structure
8. Update `flux-system/` CRs with correct prune policies per model

### Phase 3: Update Documentation (Day 3)
9. Rewrite `README.md` — remove Dex references, show all three models
10. Rewrite `ntnx-nkp-tpl-gitops.md` — update agentic instructions for all models
11. Create deployment-specific guides in `docs/guides/`
12. Create new ADRs for version management and prune policy decisions
13. Update troubleshooting runbooks

### Phase 4: Update Scripts (Day 4)
14. Update `validate-overlay.sh` — works with all three models
15. Update `render.sh` — works with all three models
16. Create `verify-prune.sh` — checks that platform objects have `prune: false` and app resources have `prune: true`

### Phase 5: Push to GitHub (Day 5)
17. Commit all changes
18. Push to `fernandoquinino-ntx/ntnx-nkp-tpl-gitops`

## Key Changes from v1 to v2

| Aspect | v1 (Current) | v2 (Planned) |
|---|---|---|
| **Scope** | Dex-only | Three deployment models |
| **Directory names** | `identity-access/dex` | `appdeployments/`, `helm-releases/`, `custom-crds/` |
| **Version management** | Inline in cluster-vars | Centralized ConfigMap + kustomize replacements |
| **Prune policy** | All `prune: false` | `prune: true` for apps, `prune: false` for platform |
| **Cluster routing** | Not addressed | `clusterConfigOverrides` for AppDeployments |
| **Documentation** | Dex-focused | Model-specific guides |
| **New file** | — | `PRACTICES.md` (concise rules), `verify-prune.sh` |

## Success Criteria

- [ ] No Dex-specific terminology in directory names or structure
- [ ] Three worked examples: one AppDeployment, one HelmRelease, one Custom CRD
- [ ] Version management via centralized ConfigMap + kustomize replacements
- [ ] Prune policy is model-appropriate (apps = true, platform = false)
- [ ] Cluster routing documented for AppDeployments
- [ ] `PRACTICES.md` is a standalone reference that can be followed without reading `ntnx-nkp-tpl-gitops.md`
- [ ] All three models pass `validate-overlay.sh` and `render.sh`
- [ ] `verify-prune.sh` catches misconfigured prune policies

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Template becomes too complex with 3 models | Keep each model's directory structure identical; only the CR content differs |
| Kustomize replacements add cognitive load | Document the pattern clearly in `PRACTICES.md` and `docs/specs/version-management.md` |
| `prune: true` could delete platform objects accidentally | `verify-prune.sh` catches this; ADR documents the decision |
| Users still copy Dex examples verbatim | README and guides explicitly state "replace with your app" |
