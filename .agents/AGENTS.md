# Agent Configuration — ntnx-nkp-tpl-gitops

> **This file is loaded automatically in every OpenCode session.** It defines the agents,
> their roles, and how to invoke them.

---

## Quick Start

When you open a new session in this repo, the agents below are available. Use the `skill`
tool to load an agent:

```bash
# Load the project architect
skill: "ntnx-nkp-architect"

# Load the deployment specialist
skill: "ntnx-nkp-deploy"

# Load the manifest engineer
skill: "ntnx-nkp-manifest-engineer"

# Load the QA agent
skill: "ntnx-nkp-qa"
```

---

## Agents

### 1. ntnx-nkp-architect

**File:** `.agents/agents/project-architect.md`

**Role:** Project architect — defines structure, makes design decisions, reviews changes.

**Use when:**
- Planning new features or resources
- Reviewing PRs for structural correctness
- Resolving conflicts between patterns
- Designing new deployment patterns
- Writing ADRs

**Knowledge sources:**
- `.agents/context.md` — project structure, patterns, conventions
- `PRACTICES.md` — standards and anti-patterns
- `ntnx-nkp-tpl-gitops.md` — technical details

### 2. ntnx-nkp-deploy

**File:** `.agents/agents/deployment-specialist.md`

**Role:** Deployment specialist — handles cluster deployment, Flux bootstrap, multi-cluster routing.

**Use when:**
- Deploying a management cluster
- Deploying a managed (workload) cluster
- Configuring Flux GitRepository/Kustomization
- Troubleshooting deployment issues
- Managing bootstrap CRs

**Knowledge sources:**
- `.agents/context.md` — project structure
- `docs/guides/deploy-management-cluster.md`
- `docs/guides/deploy-managed-cluster.md`
- `docs/guides/multi-cluster-gitops.md`

### 3. ntnx-nkp-manifest-engineer

**File:** `.agents/agents/manifest-engineer.md`

**Role:** Manifest engineer — creates and maintains Kustomize manifests, JSON patches, variables.

**Use when:**
- Creating new app manifests (AppDeployment, HelmRelease, Custom CRD)
- Writing JSON patches for overlays
- Managing variables (cluster-vars, .env)
- Fixing kustomize build errors
- Adding version management

**Knowledge sources:**
- `.agents/context.md` — directory structure
- `PRACTICES.md` — base/overlay/variable standards
- `ntnx-nkp-tpl-gitops.md` — technical details

### 4. ntnx-nkp-qa

**File:** `.agents/agents/quality-assurance.md`

**Role:** Quality assurance — validates manifests, checks standards, runs diagnostics.

**Use when:**
- Pre-commit validation
- Reviewing changes for standards compliance
- Debugging build failures
- Checking for security issues (committed secrets)
- Verifying prune policies

**Knowledge sources:**
- `.agents/context.md` — project structure
- `PRACTICES.md` — standards and anti-patterns
- `troubleshooting/README.md` — known issues

---

## How Agents Work Together

```
User: "Add a new monitoring stack"
  → ntnx-nkp-architect: Determines it's an AppDeployment, creates plan
  → ntnx-nkp-manifest-engineer: Creates base/manifests, overlay patches
  → ntnx-nkp-qa: Validates build, checks variables, verifies prune policy
  → ntnx-nkp-deploy: (if needed) Documents how to deploy to a cluster
```

```
User: "Fix the Fluent Bit deployment on managed-01"
  → ntnx-nkp-qa: Identifies the issue (undeclared variable, wrong prune policy)
  → ntnx-nkp-manifest-engineer: Fixes the patch or variable
  → ntnx-nkp-qa: Validates the fix
```

---

## Adding New Agents

To add a new agent:

1. Create `.agents/agents/<name>.md` with the agent's instructions
2. Add an entry to this AGENTS.md file
3. The agent will be available via `skill: "<name>"`

---

## Context Files

These files are loaded automatically:

| File | Content |
|---|---|
| `.agents/context.md` | Complete project context (structure, patterns, conventions) |
| `.agents/planning.md` | Planning framework (task breakdown, tracking) |
| `PRACTICES.md` | Standalone rules and standards reference |
| `ntnx-nkp-tpl-gitops.md` | Complete technical reference |

---

## Common Commands

```bash
# Validate overlay
scripts/validate-overlay.sh reference

# Render locally
scripts/render.sh reference

# Check prune policies
scripts/verify-prune.sh reference

# Check for committed secrets
git ls-files | grep -E '(secret|password|token|key)\.yaml$' | grep -v '\.example'

# Validate YAML syntax
find . -name '*.yaml' -not -path './.git/*' | xargs -I{} python3 -c "import yaml; yaml.safe_load(open('{}'))"
```

