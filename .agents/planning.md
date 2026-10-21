# Planning Framework — ntnx-nkp-tpl-gitops

> **Auto-loaded in every session.** Use this framework to break down tasks, track progress,
> and maintain consistency across sessions.

---

## Task Breakdown Rules

### Rule 1: Always Start with PRACTICES.md
Before implementing anything, read `PRACTICES.md` to understand which category the work falls
into and what standards apply.

### Rule 2: One Concept Per Change
Each commit should address one logical unit:
- One new app
- One new cluster
- One fix
- One documentation update

### Rule 3: Validate Before Commit
Every change MUST pass validation:
```bash
scripts/validate-overlay.sh reference
scripts/render.sh reference
scripts/verify-prune.sh reference
```

### Rule 4: Follow the Decision Flow
```
Is this a cluster definition?
  → First cluster → base/management-cluster/
  → Workload → base/managed-clusters/<name>/
  → Day-2 app → Which model?
    → NKP ClusterApp → appdeployments/
    → Helm chart → helm-releases/
    → Platform CR → custom-crds/
```

---

## Adding a New App

```
1. Read PRACTICES.md Section 3 (model selection)
2. Create base/<model>/<app>/ with templates
3. Create overlay/.../patches/<model>/<app>/ with JSON patches
4. Register in aggregator (kustomization.yaml components:)
5. Add variables to cluster-vars.yaml and .env.example
6. Validate: scripts/validate-overlay.sh reference
7. Test render: scripts/render.sh reference
8. Commit with descriptive message
```

## Adding a New Managed Cluster

```
1. Read docs/guides/deploy-managed-cluster.md
2. Create base/managed-clusters/<name>/ with NKPCluster template
3. Create overlay/.../managed-<name>/ with patches
4. Create overlay/.../bootstrap/<name>-kustomization.yaml
5. Add variables to cluster-vars.yaml
6. Validate: scripts/validate-overlay.sh reference
7. Commit
```

## Adding a New Managed Cluster

```
1. Read docs/guides/deploy-managed-cluster.md
2. Create base/managed-clusters/<name>/ with NKPCluster template
3. Create overlay/.../managed-<name>/ with patches
4. Create overlay/.../bootstrap/<name>-kustomization.yaml
5. Add variables to cluster-vars.yaml
6. Validate: scripts/validate-overlay.sh reference
7. Commit
```

## Fixing a Bug

```
1. Read troubleshooting/README.md for known issues
2. Identify root cause
3. Fix in the appropriate layer:
   - base/ issue → fix template, update patches if needed
   - overlay/ issue → fix JSON patch, update cluster-vars
   - script issue → fix script logic
4. Validate: scripts/validate-overlay.sh reference
5. Add troubleshooting runbook if new symptom
6. Commit
```

---

## Progress Tracking

Use a todo list to track multi-step work:

```
[ ] Step 1: ...
[ ] Step 2: ...
[ ] Step 3: ...
```

Mark each step complete before moving to the next. If interrupted, resume from the last
incomplete step.

---

## Commit Message Convention

```
<type>: <summary>

- Added: new files, features
- Changed: modifications to existing files
- Fixed: bug fixes
- Updated: documentation, scripts
- Removed: deleted files

Examples:
  feat: add fluent-bit AppDeployment
  fix: correct prune policy on mgmt Kustomization
  docs: update PRACTICES.md for multi-cluster
```

