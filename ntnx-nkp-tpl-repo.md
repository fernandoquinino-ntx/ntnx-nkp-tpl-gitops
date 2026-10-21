---
title: ntnx-nkp-tpl-repo — Template Repository Reference
tags: [template, kustomize, kubernetes, flux, gitops, standards, agentic-instructions]
sourceRefs: []
lastReviewed: 2025-01-23
---

# ntnx-nkp-tpl-repo — Template Repository Reference

> **Purpose:** This document defines the rules, standards, and agentic instructions for creating and maintaining a Kustomize-based NKP application repository. Use this as the single source of truth when bootstrapping a new repo or reviewing an existing one.

---

## 0. Quick Reference — What This Pattern Is

This pattern is a **Kustomize base-overlay repository** for configuring NKP/Kommander applications. It separates:

- **`base/`** — generic, cluster-agnostic templates with `${VAR}` placeholders
- **`overlay/clusters/<cluster>/`** — per-cluster overrides (JSON patches, variable values, secret references)
- **`flux-system/`** — Flux GitOps CRs that sync manifests and substitute variables

The pattern supports **provider switching** via Kustomize Components, enabling drop-in replacement of identity providers, storage backends, network plugins, etc.

---

## 1. Repository Structure

Every repo following this pattern MUST have this top-level structure:

```
<repo>/
├── base/                          # GENERIC templates (immutable, no cluster-specific values)
│   └── cluster-apps/
│       └── <category>/            # logical grouping (e.g., identity-access, networking)
│           ├── kustomization.yaml # aggregator: lists apps in this category
│           └── <app>/             # one app = one Kustomization directory
│               ├── kustomization.yaml
│               ├── <resource>.yaml    # CRs with ${VAR} placeholders
│               ├── providers/         # swappable provider implementations
│               │   ├── <provider-a>/
│               │   │   ├── kustomization.yaml
│               │   │   └── patch.yaml
│               │   └── <provider-b>/
│               │       ├── kustomization.yaml
│               │       └── patch.yaml
│               └── secrets/         # credential Secret templates (gitignored in overlay)
│                   └── <secret>/
│                       ├── kustomization.yaml
│                       └── secret.yaml
├── overlay/                       # PER-CLUSTER overrides
│   └── clusters/
│       └── reference/             # 🔑 REFERENCE cluster — copy this for real clusters
│           ├── cluster-vars.yaml  # ConfigMap: non-secret ${VAR} values
│           ├── .env.example       # .env template for local renders
│           ├── cluster-apps/
│           │   ├── kustomization.yaml     # aggregator: components: [patches/*]
│           │   └── patches/
│           │       └── <category>/
│           │           └── <app>/
│           │               ├── kustomization.yaml   # kind: Component
│           │               └── providers/
│           │                   └── <default-provider>/
│           │                       ├── kustomization.yaml
│           │                       ├── patch.yaml
│           │                       └── secret-patch.yaml.example
│           └── flux-system/
│               ├── gitrepository.yaml       # Flux source CR
│               └── 01-cluster-apps.yaml     # Flux Kustomization CR
├── scripts/                       # utility scripts (validate, render, etc.)
│   ├── validate-overlay.sh
│   ├── render.sh
│   └── ...
├── docs/
│   ├── adr/                       # Architecture Decision Records
│   ├── guides/                    # how-to guides
│   └── specs/                     # technical specifications
├── troubleshooting/               # symptom → cause → fix runbooks
├── specs/                         # feature specs (optional)
├── .specify/                      # spec templates (optional)
├── .gitignore
└── README.md
```

### Rules

- **RULE 1:** `base/` MUST contain only generic templates. No IPs, DNs, passwords, hostnames, or cluster-specific values.
- **RULE 2:** Every directory under `base/cluster-apps/<category>/` MUST be a self-contained Kustomization (has its own `kustomization.yaml`).
- **RULE 3:** Every app MUST have at least one provider under `providers/`. The default provider is named descriptively (e.g., `ad`, `default`, `internal`).
- **RULE 4:** `overlay/clusters/` MUST contain a `reference/` cluster. No real cluster overlay exists until someone copies `reference/`.
- **RULE 5:** Every cluster overlay MUST include `flux-system/` with `gitrepository.yaml` and `01-cluster-apps.yaml`.
- **RULE 6:** Scripts directory MUST include `validate-overlay.sh` and `render.sh`.

---

## 2. Base Layer Standards

### 2.1 Kustomization Files

Every `kustomization.yaml` in `base/` MUST:

- Use `apiVersion: kustomize.config.k8s.io/v1beta1` (NOT `v1alpha1` — that's for Components).
- List resources explicitly. Never use `generators` for secrets (use `stringData` in plain Secret files instead).
- Include a comment at the top explaining what the directory contains.

```yaml
# base/cluster-apps/<category>/<app>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# This directory contains <description>.
# Resources listed here are SHARED across all providers.
resources:
  - <resource>.yaml

# NO secretGenerator — use plain Secret + stringData so ${VAR} stays visible to Flux postBuild.
```

### 2.2 Resource Files

Every CR in `base/` MUST:

- Use `${VAR}` placeholders for every value that differs per cluster.
- Include inline comments explaining each field.
- Have a `metadata.name` that is stable (not `${VAR}`).
- Be placed in `base/cluster-apps/<category>/<app>/` or a subdirectory like `connectors/` or `secrets/`.

```yaml
# Example: base/cluster-apps/<category>/<app>/<resource>.yaml
apiVersion: <api-group>/<version>
kind: <Kind>
metadata:
  name: <stable-name>          # NEVER a ${VAR}
  namespace: kommander
spec:
  someField: "${SOME_VAR}"     # ${VAR} placeholder — overridden in overlay
  anotherField: "literal"      # literal value is fine if it never changes
```

### 2.3 Provider Directories

Each provider under `base/cluster-apps/<category>/<app>/providers/<name>/` MUST:

- Have its own `kustomization.yaml` listing its resources.
- Contain exactly one primary resource (e.g., a Connector CR, a Deployment, etc.).
- Be inert until referenced by an overlay Component.

```yaml
# base/cluster-apps/<category>/<app>/providers/<name>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: [resource.yaml]
```

### 2.4 Secret Templates

Secrets in `base/` MUST:

- Use `stringData` (NOT `secretGenerator`).
- Contain a `PLACEHOLDER` value (not a real secret).
- Have a `kustomization.yaml` referencing the secret file.

```yaml
# base/cluster-apps/<category>/<app>/secrets/<name>/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: <name>
  namespace: kommander
type: Opaque
stringData:
  key: "PLACEHOLDER_VALUE"     # NEVER a real secret
```

### 2.5 Base README

Every `base/` directory MUST have a `README.md` that:

- Explains what the directory contains.
- Shows the directory tree.
- Links to the full app reference (usually `base/cluster-apps/<category>/<app>/README.md`).
- States that `base/` is immutable and cluster-specific values belong in the overlay.

---

## 3. Overlay Layer Standards

### 3.1 Cluster Overlay Structure

Every cluster overlay under `overlay/clusters/<name>/` MUST have:

```
overlay/clusters/<name>/
├── cluster-vars.yaml          # ConfigMap of non-secret ${VAR} values
├── .env.example               # .env template for local renders
├── cluster-apps/
│   ├── kustomization.yaml     # aggregator: components: [patches/*]
│   └── patches/
│       └── <category>/
│           └── <app>/
│               ├── kustomization.yaml   # kind: Component
│               └── providers/
│                   └── <provider>/
│                       ├── kustomization.yaml
│                       ├── patch.yaml
│                       └── secret-patch.yaml.example
└── flux-system/
    ├── gitrepository.yaml
    └── 01-cluster-apps.yaml
```

### 3.2 Cluster Vars

`cluster-vars.yaml` MUST:

- Be a `ConfigMap` with `apiVersion: v1`.
- Have `metadata.name: cluster-vars` and `metadata.namespace: kommander-flux`.
- Contain only non-secret values. Secrets go in `cluster-secrets` (referenced in Flux Kustomization).
- Include comments explaining each variable.

```yaml
# overlay/clusters/<name>/cluster-vars.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-vars
  namespace: kommander-flux
data:
  # <category> — <provider>
  SOME_VAR: "concrete-value-or-${VAR}"
  ANOTHER_VAR: "another-value"
```

### 3.3 .env.example

`.env.example` MUST:

- List ALL variables that appear in the cluster's manifests.
- Use `KEY="value"` format (quoted).
- Include both secret and non-secret variables (for local rendering only).
- Never be committed with real values — always `.example`.

### 3.4 Overlay Kustomization (Aggregator)

The overlay's `cluster-apps/kustomization.yaml` MUST:

- Use `kind: Kustomization` (NOT Component).
- List patches as `components:` (NOT `resources:`).
- Include a comment explaining the aggregation pattern.

```yaml
# overlay/clusters/<name>/cluster-apps/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Aggregator — links to each app's self-contained overlay folder.
# Add an app by adding one entry under components:.
components:
  - patches/<category>/<app>
```

### 3.5 Overlay Component

Each overlay Component under `patches/<category>/<app>/` MUST:

- Use `apiVersion: kustomize.config.k8s.io/v1alpha1` and `kind: Component`.
- Reference the base app via relative path (`../../../../../../../base/cluster-apps/<category>/<app>`).
- Select ONE provider via `components:`.
- Include a comment explaining the provider switch.

```yaml
# overlay/clusters/<name>/cluster-apps/patches/<category>/<app>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

# <App> — TOP Component. Selects ONE provider via components:.
#
#   PROVIDER SWITCH:  components: [providers/<provider-a>]   <->   [providers/<provider-b>]
resources:
  - ../../../../../../../base/cluster-apps/<category>/<app>
components:
  - providers/<default-provider>   # ← switch to providers/<other> to change provider
```

### 3.6 Provider Patch Component

Each provider patch under `patches/<category>/<app>/providers/<name>/` MUST:

- Use `kind: Component`.
- Reference its base provider via relative path.
- Include JSON patches targeting resources by `group/version/kind/name`.
- Have a `secret-patch.yaml.example` (gitignored real file).

```yaml
# overlay/clusters/<name>/cluster-apps/patches/<category>/<app>/providers/<name>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
resources:
  - ../../../../../../../../../base/cluster-apps/<category>/<app>/providers/<name>
patches:
  - path: patch.yaml
    target: { group: <api-group>, version: <version>, kind: <Kind>, name: <resource-name> }
```

### 3.7 JSON Patches

All patches MUST use RFC 6902 format:

```yaml
# overlay/clusters/<name>/cluster-apps/patches/<category>/<app>/providers/<name>/patch.yaml
- op: replace
  path: /spec/<field>
  value: "concrete-value"          # or "${VAR}" for Flux substitution

- op: add
  path: /spec/<newField>
  value: "new-value"

- op: remove
  path: /spec/<fieldToRemove>
```

**Rules for patches:**
- Use `op: replace` to change existing fields.
- Use `op: add` to add new fields.
- Use `op: remove` to drop fields.
- Target resources by `group/version/kind/name` — never by index.
- Use `${VAR}` for values that come from `cluster-vars.yaml` or `.env`.
- Commit concrete values ONLY for the `reference` cluster. Real clusters should use `${VAR}`.

### 3.8 Secret Patches

Secret patches MUST:

- Be committed as `secret-patch.yaml.example`.
- Be gitignored as `secret-patch.yaml`.
- Use RFC 6902 patches targeting the Secret's `stringData`.
- Reference `${VAR}` (not concrete values) so Flux can substitute from `cluster-secrets`.

```yaml
# overlay/clusters/<name>/.../secret-patch.yaml.example
- op: replace
  path: /stringData/<key>
  value: "${SOME_SECRET_VAR}"
```

### 3.9 Flux System CRs

`flux-system/gitrepository.yaml` MUST:

- Use `apiVersion: source.toolkit.fluxcd.io/v1` and `kind: GitRepository`.
- Reference the repo URL and branch.
- Include a `secretRef` for authentication.

```yaml
# overlay/clusters/<name>/flux-system/gitrepository.yaml
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

`flux-system/01-cluster-apps.yaml` MUST:

- Use `apiVersion: kustomize.toolkit.fluxcd.io/v1` and `kind: Kustomization`.
- Set `prune: false` for Kommander objects (never cascade-delete).
- Include `postBuild.substituteFrom` referencing `cluster-vars` ConfigMap and `cluster-secrets` Secret.

```yaml
# overlay/clusters/<name>/flux-system/01-cluster-apps.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: <app-name>
  namespace: kommander-flux
spec:
  interval: 5m
  prune: false
  sourceRef:
    kind: GitRepository
    name: <repo-name>
    namespace: kommander-flux
  path: ./overlay/clusters/<name>/cluster-apps
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-vars
      - kind: Secret
        name: cluster-secrets
        optional: true
```

---

## 4. Scripts Standards

### 4.1 validate-overlay.sh

MUST:

- Accept a cluster name as argument (default: `reference`).
- Run `kustomize build` on the overlay.
- Extract all `${VAR}` placeholders from the build output.
- Compare against declared vars in `cluster-vars.yaml` and `.env.example`.
- Exit non-zero if any `${VAR}` is undeclared.

```bash
#!/usr/bin/env bash
# validate-overlay.sh — build an overlay and verify every ${VAR} is declared.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CLUSTER="${1:-reference}"
PATH_TO_BUILD="overlay/clusters/${CLUSTER}/cluster-apps"
VARS_FILE="overlay/clusters/${CLUSTER}/cluster-vars.yaml"
ENV_EXAMPLE="overlay/clusters/${CLUSTER}/.env.example"

# ... (build + extract + compare logic)
```

### 4.2 render.sh

MUST:

- Accept a cluster name and optional target path.
- Load `.env` (NOT `.env.example`) from the cluster directory.
- Run `envsubst` on all files containing `${VAR}` placeholders.
- Output rendered files to `/tmp/<repo-name>/render/<cluster>/`.
- Whitelist only variables referenced in the target tree.

```bash
#!/usr/bin/env bash
# render.sh — render ${VAR} placeholders locally with GNU envsubst.
set -euo pipefail

# ... (load .env + envsubst logic)
```

---

## 5. Documentation Standards

### 5.1 README.md (Root)

MUST include:

- Project name and one-line description.
- Table of contents mapping each path to its purpose.
- Quickstart section with `validate-overlay.sh` and `render.sh` commands.
- "How it works" section explaining the architecture.
- "Applying to a real cluster" section with copy-and-edit instructions.
- Troubleshooting runbook index.
- Any tooling sections (backup/restore, etc.).

### 5.2 Base README

`base/cluster-apps/<category>/<app>/README.md` MUST:

- Be a complete reference for every field in every resource in that directory.
- Include tables for each configurable option (option, type, required, meaning).
- Show override recipes (copy-paste JSON patches for common scenarios).
- Document how to validate and apply.
- List troubleshooting gotchas.
- Reference the source CRD or API documentation.

### 5.3 ADRs

Every architectural decision MUST be documented as an ADR in `docs/adr/`:

- Filename: `NNNN-<slug>.md` (zero-padded 4-digit number).
- Format: Title, Context, Decision, Consequences.
- Include a summary table in `docs/adr/README.md`.

```markdown
# NNNN-<slug>

**Date:** YYYY-MM-DD
**Status:** Proposed | Accepted | Deprecated | Superseded

## Context
[What is the issue or opportunity?]

## Decision
[What did we decide to do?]

## Consequences
[What are the resulting consequences, both positive and negative?]
```

### 5.4 Troubleshooting Runbooks

Each runbook in `troubleshooting/` MUST:

- Be named after the symptom (e.g., `strong-auth-required.md`).
- Include: symptom, cause, diagnosis steps, fix, prevention.
- Reference relevant base files and overlay paths.
- Be linked from `troubleshooting/README.md`.

```markdown
# <Symptom>

## Symptom
[What does the user see?]

## Cause
[Why does this happen?]

## Diagnosis
[How to confirm this is the cause?]

## Fix
[Step-by-step resolution]

## Prevention
[How to avoid this in the future]
```

---

## 6. Secret Management Standards

### 6.1 Committing Secrets

- **NEVER** commit real secrets to git.
- **ALWAYS** commit `*.example` templates for secret files.
- Secret files that are gitignored: `secret.yaml`, `secret-patch.yaml`, `.env`, `ca-secret.yaml`.
- Committed examples: `secret.yaml.example`, `secret-patch.yaml.example`, `.env.example`, `ca-secret.yaml.example`.

### 6.2 Secret File Naming

Use consistent naming:

- `secret.yaml` — base template in `base/cluster-apps/<category>/<app>/secrets/<name>/`
- `secret-patch.yaml.example` — overlay template in `overlay/clusters/<cluster>/.../providers/<name>/`
- `secret-patch.yaml` — real file (gitignored)

### 6.3 Secret Delivery

Secrets reach the cluster via one of:

1. **Flux postBuild** — `${VAR}` in `secret-patch.yaml` substituted from `cluster-secrets` Secret.
2. **ESO (External Secrets Operator)** — Secret managed from Vault/KV store (manual apply reverted).
3. **Manual apply** — `kubectl apply` with a local `.env` (testing only).

---

## 7. Git Ignore Standards

`.gitignore` MUST include:

```gitignore
# Secrets / generated
overlay/clusters/*/.env
overlay/**/secret-patch.yaml
overlay/**/secret.yaml
overlay/**/*secret*.yaml
overlay/**/*sops*.yaml
overlay/**/*credentials*.yaml

# Committed examples are tracked
!overlay/**/*.example

# OS / editor
.DS_Store
*.swp

# Backup output (may contain secrets)
backup/
**/backup/
```

---

## 8. Agentic Instructions

These are instructions for AI agents working with this repository pattern.

### 8.1 When Creating a New Repo

```
You are creating a new NKP application repository following the ntnx-nkp-tpl-repo pattern.

Step 1: Create the directory structure per Section 1.
Step 2: Write base/cluster-apps/<category>/<app>/kustomization.yaml listing shared resources.
Step 3: Write each resource YAML with ${VAR} placeholders and inline comments.
Step 4: Write providers/<name>/kustomization.yaml and resource.yaml for each provider.
Step 5: Write secrets/<name>/kustomization.yaml and secret.yaml with PLACEHOLDER values.
Step 6: Write base/cluster-apps/<category>/<app>/README.md as a complete field reference.
Step 7: Write base/README.md explaining the directory.
Step 8: Create overlay/clusters/reference/ with cluster-vars.yaml, .env.example, and all patches.
Step 9: Write overlay/clusters/reference/cluster-apps/kustomization.yaml (aggregator).
Step 10: Write overlay Component kustomization.yaml with provider switch comment.
Step 11: Write provider patch components with JSON patches targeting by group/version/kind/name.
Step 12: Write secret-patch.yaml.example for each provider.
Step 13: Write flux-system/gitrepository.yaml and 01-cluster-apps.yaml.
Step 14: Write scripts/validate-overlay.sh and scripts/render.sh.
Step 15: Write README.md, ADRs, troubleshooting runbooks, and .gitignore.
Step 16: Validate with: scripts/validate-overlay.sh reference
Step 17: Test render with: scripts/render.sh reference
```

### 8.2 When Adding a New App to an Existing Repo

```
You are adding a new application to an existing ntnx-nkp-tpl-repo repository.

Step 1: Under base/cluster-apps/, create a new category or use an existing one.
Step 2: Create <app>/ with kustomization.yaml, resource files, providers/, and secrets/.
Step 3: Write ${VAR} placeholders in all resource files.
Step 4: Write base/cluster-apps/<category>/<app>/README.md.
Step 5: Add the app to base/cluster-apps/<category>/kustomization.yaml resources list.
Step 6: Create overlay/clusters/reference/cluster-apps/patches/<category>/<app>/ directory.
Step 7: Write the overlay Component kustomization.yaml referencing the base.
Step 8: Write provider patches (JSON patches + secret-patch.yaml.example).
Step 9: Add the patch to overlay/clusters/reference/cluster-apps/kustomization.yaml components list.
Step 10: Add any new variables to cluster-vars.yaml and .env.example.
Step 11: Validate: scripts/validate-overlay.sh reference
Step 12: Test render: scripts/render.sh reference
```

### 8.3 When Switching Providers

```
You are switching the default provider for an app in an ntnx-nkp-tpl-repo repository.

Step 1: Identify the overlay Component at overlay/clusters/<cluster>/cluster-apps/patches/<category>/<app>/kustomization.yaml.
Step 2: Change the components line from `providers/<old>` to `providers/<new>`.
Step 3: Ensure the new provider has a base under base/cluster-apps/<category>/<app>/providers/<new>/.
Step 4: Ensure the new provider has a patch component under overlay/.../providers/<new>/.
Step 5: Update cluster-vars.yaml with any new variables needed by the new provider.
Step 6: Update .env.example with any new variables.
Step 7: Validate: scripts/validate-overlay.sh <cluster>
Step 8: Test render: scripts/render.sh <cluster>
```

### 8.4 When Creating a Real Cluster Overlay

```
You are creating a real cluster overlay by copying the reference cluster.

Step 1: Copy the reference: cp -r overlay/clusters/reference overlay/clusters/<cluster-name>
Step 2: Edit overlay/clusters/<cluster-name>/cluster-vars.yaml with real values (or ${VAR} for Flux).
Step 3: Create overlay/clusters/<cluster-name>/.env from .env.example and fill in real values.
Step 4: For each provider, copy secret-patch.yaml.example to secret-patch.yaml (or use ${VAR}).
Step 5: If using a non-default provider, update the overlay Component's components line.
Step 6: Update flux-system/gitrepository.yaml if the repo URL differs.
Step 7: Validate: scripts/validate-overlay.sh <cluster-name>
Step 8: Test render: scripts/render.sh <cluster-name>
Step 9: Apply: kubectl apply -k overlay/clusters/<cluster-name>/cluster-apps
```

### 8.5 When Reviewing a Repo

```
You are reviewing a repository for compliance with the ntnx-nkp-tpl-repo pattern.

Checklist:
[ ] base/ contains only generic templates (no IPs, DNs, passwords, hostnames)
[ ] Every resource uses ${VAR} for cluster-specific values
[ ] Every base directory has a kustomization.yaml
[ ] Every app has at least one provider under providers/
[ ] overlay/clusters/ contains a reference/ cluster
[ ] Every cluster overlay has cluster-vars.yaml and .env.example
[ ] Overlay Components use kind: Component (NOT Kustomization)
[ ] Overlay Components use v1alpha1 (NOT v1beta1)
[ ] Base Kustomizations use v1beta1 (NOT v1alpha1)
[ ] JSON patches target resources by group/version/kind/name
[ ] Secret files are gitignored; *.example files are committed
[ ] flux-system/ contains gitrepository.yaml and 01-cluster-apps.yaml
[ ] 01-cluster-apps.yaml has postBuild.substituteFrom referencing cluster-vars
[ ] 01-cluster-apps.yaml has prune: false
[ ] scripts/validate-overlay.sh exists and works
[ ] scripts/render.sh exists and works
[ ] README.md includes quickstart, how-it-works, and applying instructions
[ ] base/cluster-apps/<app>/README.md is a complete field reference
[ ] docs/adr/ contains ADRs for architectural decisions
[ ] troubleshooting/ contains runbooks for known issues
[ ] .gitignore covers secrets, .env, and generated files
[ ] scripts/validate-overlay.sh reference passes
[ ] scripts/render.sh reference produces valid YAML (no undeclared ${VAR})
```

### 8.6 When Writing JSON Patches

```
When writing RFC 6902 JSON patches for the overlay:

RULES:
1. Target by identity: { group, version, kind, name } — never by index.
2. Use op: replace for existing fields, op: add for new fields, op: remove for dropping fields.
3. Use JSON pointer paths: /spec/field/nestedField (NOT /metadata/name).
4. Use ${VAR} for values from cluster-vars.yaml or .env — commit concrete values only for reference.
5. Keep patches minimal — only override what differs from base.
6. Never change metadata.name or metadata.namespace in a patch (those are stable).
7. For secrets, patch /stringData/key — never /data/key (base64 encoded).
8. Document each patch with a comment explaining why it exists.

EXAMPLE:
- op: replace
  path: /spec/ldap/host
  value: "dc01.ad.example.local:636"     # concrete for reference, ${VAR} for real clusters

- op: add
  path: /spec/ldap/rootCASecretRef
  value: { name: "${DEX_LDAP_ROOT_CA_SECRET}" }
```

### 8.7 When Writing Variables

```
When defining ${VAR} placeholders and their declarations:

RULES:
1. Variable names: UPPERCASE with underscores (e.g., DEX_LDAP_HOST, OKTA_ISSUER).
2. Non-secret vars go in cluster-vars.yaml (ConfigMap, namespace: kommander-flux).
3. Secret vars go in cluster-secrets (Secret, referenced in Flux postBuild).
4. Both must be listed in .env.example for local rendering.
5. Every ${VAR} in the build output MUST be declared — validate catches undeclared vars.
6. Use descriptive names: <APP>_<FIELD> or <CATEGORY>_<FIELD>.
7. Document each variable in cluster-vars.yaml with a comment.
8. If a variable has a default in base/, still declare it in cluster-vars.yaml.

EXAMPLE:
# cluster-vars.yaml
data:
  # Dex LDAP connector settings
  DEX_LDAP_HOST: "dc01.ad.example.local:636"
  DEX_LDAP_BIND_DN: "CN=svc-nkp,CN=Users,DC=ad,DC=example,DC=local"
  DEX_LDAP_INSECURE_SKIP_VERIFY: "true"
```

---

## 9. Validation Checklist

Before committing any change to an ntnx-nkp-tpl-repo:

```bash
# 1. Validate the reference overlay
scripts/validate-overlay.sh reference

# 2. Render the reference overlay locally
scripts/render.sh reference

# 3. Inspect rendered output for correctness
ls /tmp/ntnx-render/reference/
diff -ru <original> /tmp/ntnx-render/reference/

# 4. Check for undeclared variables
grep -r '\${[A-Z_][A-Z0-9_]*}' overlay/ --include='*.yaml' | sort -u

# 5. Verify no secrets are committed
git ls-files | grep -E '(secret|password|token|key)\.yaml$' | grep -v '\.example'

# 6. Verify all .example files are committed
git ls-files | grep '\.example$'
```

---

## 10. Common Anti-Patterns (Avoid These)

| Anti-Pattern | Why It's Wrong | Correct Approach |
|---|---|---|
| Putting concrete IPs in `base/` | Breaks the separation of concerns | Use `${VAR}`, set in overlay |
| Using `secretGenerator` | Base64-encodes values, hiding `${VAR}` from Flux | Use plain Secret + `stringData` |
| Editing `base/` for a cluster | Breaks reusability, causes merge conflicts | Create overlay patches |
| Using `resources:` instead of `components:` in overlay aggregator | Mixes patches with base resources | Use `components:` for patches |
| Using `v1alpha1` in base Kustomizations | Wrong API version for Kustomizations | Use `v1beta1` in base, `v1alpha1` only for Components |
| Committing real secrets | Security risk | Commit `*.example`, gitignore real files |
| Hardcoding `${VAR}` in patches without declaring them | `validate-overlay.sh` catches this | Declare every `${VAR}` in `cluster-vars.yaml` or `.env` |
| Using `op: replace` on `metadata.name` | Unnecessary, names are stable in base | Only patch `spec` fields |
| Copying entire resources instead of patching | Duplicates base, hard to maintain | Use JSON patches for field-level changes |
| Forgetting `prune: false` in Flux Kustomization | Cascade-deletes Kommander objects | Always set `prune: false` for NKP resources |

---

## 11. Quick Reference Card

```
┌─────────────────────────────────────────────────────────────────┐
│  ntnx-nkp-tpl-repo Quick Reference                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  base/         → generic templates, ${VAR} placeholders         │
│  overlay/      → per-cluster overrides, JSON patches            │
│  flux-system/  → Flux GitOps CRs (GitRepository + Kustomization)│
│  scripts/      → validate-overlay.sh, render.sh                 │
│  docs/adr/     → Architecture Decision Records                  │
│  troubleshooting/ → symptom → cause → fix runbooks              │
│                                                                 │
│  Provider Switch:                                               │
│    components: [providers/ad]  →  components: [providers/okta]  │
│                                                                 │
│  Variable Flow:                                                 │
│    base: ${VAR}  →  overlay cluster-vars.yaml  →  Flux          │
│    base: ${VAR}  →  .env (local)  →  render.sh                  │
│                                                                 │
│  Secret Flow:                                                   │
│    base: stringData/PLACEHOLDER  →  overlay secret-patch.yaml   │
│    → Flux cluster-secrets Secret  →  cluster                    │
│                                                                 │
│  Validation:                                                    │
│    scripts/validate-overlay.sh <cluster>     # undeclared ${VAR}│
│    scripts/render.sh <cluster>               # local envsubst   │
│    kubectl apply -k overlay/clusters/<c>/cluster-apps  # deploy │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 12. Version History

| Version | Date | Changes |
|---|---|---|
| 1.0 | 2025-01-23 | Initial reference based on `ntnx-nkp-dex` pattern |

---

*This document is the single source of truth for the ntnx-nkp-tpl-repo pattern. When in doubt, follow the `ntnx-nkp-dex` repository as the canonical example.*
