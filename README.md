# ntnx-nkp-tpl-repo

**Kustomize base-overlay template for NKP/Kommander application repositories.**

A reference implementation for organizing Kubernetes manifests with Kustomize, Flux GitOps, and provider-switching Components — modeled after the [`ntnx-nkp-dex`](https://github.com/fernandoquinino-ntx/ntnx-nkp-dex) repository.

---

## What's Inside

| Path | Purpose |
|---|---|
| [`ntnx-nkp-tpl-repo.md`](ntnx-nkp-tpl-repo.md) | **Complete reference** — rules, standards, and agentic instructions |
| `base/cluster-apps/` | Generic templates with `${VAR}` placeholders (immutable) |
| `overlay/clusters/reference/` | Reference cluster overlay — copy this for a real cluster |
| `scripts/` | `validate-overlay.sh`, `render.sh` |
| `docs/adr/` | Architecture Decision Records |
| `docs/guides/` | How-to guides |
| `docs/specs/` | Technical specifications |
| `troubleshooting/` | Symptom → cause → fix runbooks |

---

## Quickstart

```bash
# Validate the reference overlay renders (no undeclared ${VAR})
scripts/validate-overlay.sh reference

# Local render of a cluster (${VAR} from the cluster's .env)
scripts/render.sh reference

# Apply to a cluster
kubectl apply -k overlay/clusters/<cluster>/cluster-apps
```

---

## Architecture

```
base/                          ← generic templates (no cluster-specific values)
  └── cluster-apps/
      └── <category>/
          └── <app>/
              ├── kustomization.yaml
              ├── <resource>.yaml      # CRs with ${VAR} placeholders
              ├── providers/           # swappable provider implementations
              └── secrets/             # credential Secret templates

overlay/clusters/<cluster>/          ← per-cluster overrides
  ├── cluster-vars.yaml              # non-secret ${VAR} values (ConfigMap)
  ├── .env.example                   # .env template for local renders
  ├── cluster-apps/
  │   ├── kustomization.yaml         # aggregator: components: [patches/*]
  │   └── patches/<cat>/<app>/       # Component: base ref + provider switch
  └── flux-system/
      ├── gitrepository.yaml         # Flux source CR
      └── 01-cluster-apps.yaml       # Flux Kustomization + postBuild

scripts/
  ├── validate-overlay.sh            # build + undeclared ${VAR} check
  └── render.sh                      # local envsubst rendering
```

---

## Key Concepts

### Base-Overlay Separation

- **`base/`** = generic, reusable templates. No IPs, DNs, passwords, or hostnames.
- **`overlay/`** = per-cluster overrides. Never edit `base/` for a cluster.

### Provider Switching

Switch identity providers (or any swappable component) by changing one line:

```yaml
# overlay/.../patches/<cat>/<app>/kustomization.yaml
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
kubectl apply -k overlay/clusters/<your-cluster>/cluster-apps
```

---

## Documentation

- **[Complete Reference](ntnx-nkp-tpl-repo.md)** — All rules, standards, and agentic instructions
- [ADR Index](docs/adr/README.md) — Architecture decisions
- [Overlay Model Spec](docs/specs/overlay-model.md) — How base → cluster works
- [Troubleshooting](troubleshooting/README.md) — Common issues and fixes

---

## Validation

Before committing any change:

```bash
scripts/validate-overlay.sh reference   # check undeclared ${VAR}
scripts/render.sh reference             # local envsubst test
```

---

## Anti-Patterns to Avoid

| Anti-Pattern | Correct Approach |
|---|---|
| Concrete values in `base/` | Use `${VAR}`, set in overlay |
| `secretGenerator` | Use `stringData` |
| Editing `base/` for a cluster | Create overlay patches |
| `resources:` for overlay patches | Use `components:` |
| `v1alpha1` in base Kustomizations | Use `v1beta1` in base |
| Committing real secrets | Commit `*.example`, gitignore real |
| Missing `prune: false` | Always set for NKP resources |

---

*This is a template repository. Use it as the foundation for your own NKP application repositories. See [ntnx-nkp-tpl-repo.md](ntnx-nkp-tpl-repo.md) for complete standards and agentic instructions.*
