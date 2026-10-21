# base/managed-clusters/ — Workload Cluster Manifests

Generic templates for provisioning NKP **managed (workload) clusters**.
The `NKPCluster` CR is applied to the **management cluster** (not the managed cluster itself).
The management cluster's CAPI controller provisions the workload cluster on Nutanix AHV.

## How It Works

1. `NKPCluster` CR (mode: `managed`) is applied to the management cluster's workspace namespace
2. CAPI controller creates VMs on Nutanix AHV using the NKP node image
3. Once `status.phase = Provisioned`, a `{cluster}-kubeconfig` Secret is created
4. The kubeconfig is extracted and used for Flux bootstrap on the managed cluster

## What It Renders (mode: managed)

| Resource | CRD | Notes |
|---|---|---|
| `NKPCluster` | `clusters.nkp.nutanix.com/v1alpha1` | WITHOUT `kommander.d2iq.io/host: "true"` label |
| `{cluster}-pc-credentials` | `Secret` | Prism Central auth |
| `{cluster}-pc-credentials-for-csi` | `Secret` | CSI credentials |
| `{cluster}-pc-credentials-for-konnector-agent` | `Secret` | Konnector agent auth |

**NOT included** (management-only):
- `kommander-bootstrap-configuration` ConfigMap
- `global-nutanix-credentials` Secret
- `prism-central-metadata` Secret

See [PRACTICES.md](../../PRACTICES.md) Section 10 for managed cluster standards.
