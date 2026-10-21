# Changelog

All notable changes to this template repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Management cluster manifests (base/management-cluster/)
- Managed cluster manifests (base/managed-clusters/)
- Multi-cluster overlay structure (mgmt/, managed-<name>/, bootstrap/)
- Deployment guides: management cluster, managed cluster, multi-cluster GitOps
- ADRs: managed cluster pattern, multi-cluster routing, Flux bootstrap

### Changed
- Repo renamed: ntnx-nkp-tpl-repo → ntnx-nkp-tpl-gitops
- PRACTICES.md rewritten with 5 resource categories + multi-cluster standards
- Scripts updated for multi-cluster validation
- CI workflow updated for multi-cluster checks

## [2.0.0] — 2025-01-23

### Added
- Three deployment models: AppDeployment, HelmRelease, Custom CRD
- Centralized version management via ConfigMap + kustomize replacements
- `verify-prune.sh` script for prune policy compliance
- GitHub Actions workflow for CI validation
- `PRACTICES.md` — standalone rules and standards reference
- Model-specific deployment guides

### Changed
- Restructured `base/` from Dex-specific to generic three-model layout
- Updated Flux Kustomization with `prune: true`, `wait: true`, `timeout: 5m`, `dependsOn`
- Updated all ADRs for three-model architecture

### Fixed
- Prune policy: app resources now use `prune: true` (was blanket `prune: false`)

## [1.0.0] — 2025-01-23

### Added
- Initial template repository based on `ntnx-nkp-dex` pattern
- Dex-only deployment model (Custom CRD)
- Base-overlay structure with Kustomize Components
- Provider switching (AD/LDAP ↔ Okta/OIDC)
- `validate-overlay.sh` and `render.sh` scripts
- JSON patch overlays for all resources
- Secret management with `*.example` pattern
- Flux GitOps CRs (GitRepository + Kustomization)
- ADRs, troubleshooting runbooks, documentation
- `.gitignore` for secrets and generated files

[Unreleased]: https://github.com/fernandoquinino-ntx/ntnx-nkp-tpl-gitops/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/fernandoquinino-ntx/ntnx-nkp-tpl-gitops/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/fernandoquinino-ntx/ntnx-nkp-tpl-gitops/releases/tag/v1.0.0
