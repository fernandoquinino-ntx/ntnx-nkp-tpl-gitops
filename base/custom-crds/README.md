# base/custom-crds/ — Custom CRDs

Generic templates for platform configuration CRDs that are not AppDeployments or HelmReleases.
Examples: Dex Connectors, VirtualGroups, MetalLB IPAddressPools, License CRs.

Each app directory contains:
- `<resource>.yaml` — the CR with ${VAR} placeholders
- `providers/` — Optional swappable provider implementations

See [PRACTICES.md](../../PRACTICES.md) Section 7 for complete standards.
