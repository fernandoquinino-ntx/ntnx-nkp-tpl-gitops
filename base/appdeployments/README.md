# base/appdeployments/ — Kommander AppDeployments

Generic templates for deploying NKP ClusterApps via AppDeployment CRs.
Each app directory contains:
- `<app>.appdeployment.yaml` — the AppDeployment CR with ${VAR} placeholders
- `configs/<app>-override.yaml` — Helm values ConfigMap with ${VAR} placeholders

Versions are centralized in `base/versions/app-versions.configmap.yaml` and injected
via kustomize `replacements` in the overlay.

See [PRACTICES.md](../../PRACTICES.md) Section 5 for complete standards.
