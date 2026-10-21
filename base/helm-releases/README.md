# base/helm-releases/ — Flux HelmReleases

Generic templates for deploying third-party Helm charts via Flux HelmRelease CRs.
Each app directory contains:
- `helmrepository.yaml` — Flux HelmRepository CR (chart source)
- `helmrelease.yaml` — Flux HelmRelease CR with ${VAR} placeholders

See [PRACTICES.md](../../PRACTICES.md) Section 6 for complete standards.
