# base/management-cluster/ — Management Cluster Manifests

Generic templates for provisioning an NKP **self-managed (management) cluster**.
The `NKPCluster` CR is applied to a local kind bootstrap cluster, then pivoted to the
self-managed workload cluster.

## How It Works

1. `nkp create bootstrap` creates a local kind cluster
2. `NKPCluster` CR (mode: `management`) is applied to the kind cluster
3. CAPI controller provisions VMs on Nutanix AHV
4. `nkp create capi-components` deploys CAPI to the workload cluster
5. `nkp move capi-resources` moves CAPI from kind → workload cluster
6. `nkp delete bootstrap` removes the kind cluster
7. `nkp install kommander` installs the Kommander platform

## What It Renders (mode: management)

| Resource | CRD | Notes |
|---|---|---|
| `NKPCluster` | `clusters.nkp.nutanix.com/v1alpha1` | WITH `kommander.d2iq.io/host: "true"` label |
| `{cluster}-pc-credentials` | `Secret` | Prism Central auth |
| `{cluster}-pc-credentials-for-csi` | `Secret` | CSI credentials |
| `{cluster}-pc-credentials-for-konnector-agent` | `Secret` | Konnector agent auth |
| `global-nutanix-credentials` | `Secret` (capx-system) | Global CAPI credentials |
| `prism-central-metadata` | `Secret` | PC UUID |
| `kommander-bootstrap-configuration` | `ConfigMap` | Bootstrap config |

See [PRACTICES.md](../../PRACTICES.md) Section 10 for management cluster standards.
