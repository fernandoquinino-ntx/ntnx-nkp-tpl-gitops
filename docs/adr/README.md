# ADR Index — ntnx-nkp-tpl-gitops

Decisions + rationale for the template repository. Format: `NNNN-<slug>.md`.

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-three-deployment-models.md) | Three deployment models: AppDeployment, HelmRelease, Custom CRD | Accepted |
| [0002](0002-version-management.md) | Centralized version ConfigMap + kustomize replacements | Accepted |
| [0003](0003-prune-policy.md) | Model-appropriate prune policy (apps=true, platform=false) | Accepted |
| [0004](0004-reference-cluster.md) | Ship a **reference** cluster overlay, not a real one | Accepted |
| [0005](0005-secret-example-pattern.md) | Gitignored overlay secret files + committed `*.example` | Accepted |

Add a new ADR for any decision that changes the model.
