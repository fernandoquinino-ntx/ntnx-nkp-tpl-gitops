# Changelog

All notable changes to this template repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/fernandoquinino-ntx/ntnx-nkp-tpl-repo/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/fernandoquinino-ntx/ntnx-nkp-tpl-repo/releases/tag/v1.0.0
