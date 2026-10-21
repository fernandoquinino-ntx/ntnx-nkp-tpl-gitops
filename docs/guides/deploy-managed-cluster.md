# Guide — Deploying a Managed Cluster

This guide walks through deploying a workload (managed) NKP cluster. The `NKPCluster` CR is
applied to the **management cluster** — not to the managed cluster itself.

## Prerequisites

- Management cluster already deployed and running Kommander
- NKP node image uploaded to Prism Central
- Bastion host with SSH access to the AHV cluster
- Management cluster kubeconfig

## Step 1: Prepare values

Edit `overlay/clusters/<cluster>/cluster-vars.yaml` with the managed cluster values:

```yaml
data:
  MANAGED_CLUSTER_NAME: "managed-01"
  MANAGED_CLUSTER_NAMESPACE: "kommander-default-workspace"
  PRISM_ENDPOINT: "10.0.0.100"
  PRISM_USERNAME: "admin@local"
  # PRISM_PASSWORD goes in cluster-secrets Secret
  CONTROL_PLANE_VIP: "10.0.0.201"
  LB_RANGE_START: "10.0.0.251"
  LB_RANGE_END: "10.0.0.255"
  WORKLOAD_CLUSTER_NAME: "managed-01"
  # ... other variables
```

## Step 2: Apply the managed cluster manifests

```bash
export KUBECONFIG=<mgmt-kubeconfig>

# Apply the managed cluster NKPCluster + secrets to the MANAGEMENT cluster
kubectl apply -k base/managed-clusters/managed-01
```

This creates:
- `NKPCluster` CR (mode: managed) — **NO** `kommander.d2iq.io/host: "true"` label
- 3 credential secrets (`{cluster}-pc-credentials`, `*-for-csi`, `*-for-konnector-agent`)

## Step 3: Wait for provisioning

```bash
# Wait for the CAPI Cluster CR to be Provisioned
kubectl -n kommander-default-workspace wait --for=jsonpath='{.status.phase}'=Provisioned \
  cluster/managed-01 --timeout=45m
```

## Step 4: Extract the managed cluster kubeconfig

```bash
# Extract kubeconfig from the secret created by the CAPI controller
kubectl -n kommander-default-workspace get secret managed-01-kubeconfig \
  -o jsonpath='{.data.value}' | base64 -d > managed-01.kubeconfig
```

## Step 5: Apply the managed cluster overlay (Day-2 apps)

```bash
# Apply the managed-01 overlay to the management cluster
# Flux will sync these to the managed-01 cluster via workspace membership
export KUBECONFIG=<mgmt-kubeconfig>
kubectl apply -k overlay/clusters/reference/managed-01
```

Or let Flux handle it — apply the bootstrap CRs and Flux will reconcile automatically.

## Step 6: Bootstrap Flux on the managed cluster (optional)

If you want the managed cluster to have its own Flux instance:

```bash
export KUBECONFIG=managed-01.kubeconfig

# Create the kommander-flux namespace
kubectl create namespace kommander-flux

# Apply bootstrap CRs (same structure as mgmt cluster)
kubectl apply -f <path>/bootstrap/gitrepository.yaml
kubectl apply -f <path>/bootstrap/managed-01-kustomization.yaml
```

---

## Key Differences from Management Cluster

| Aspect | Management Cluster | Managed Cluster |
|---|---|---|
| `NKPCluster` mode | `management` | `managed` |
| Host label | `kommander.d2iq.io/host: "true"` | None |
| Secrets | 5 + metadata ConfigMap | 3 only |
| Applied to | kind bootstrap cluster | Management cluster |
| Namespace | `kommander` | `kommander-default-workspace` |
| Pivot needed | Yes | No |
| Kommander install | Yes (`nkp install kommander`) | No (managed by mgmt cluster) |

---

## Variable Reference

| Variable | Example | Description |
|---|---|---|
| `MANAGED_CLUSTER_NAME` | `managed-01` | Cluster name |
| `MANAGED_CLUSTER_NAMESPACE` | `kommander-default-workspace` | Workspace namespace |
| `PRISM_ENDPOINT` | `10.0.0.100` | Prism Central IP/FQDN |
| `PRISM_USERNAME` / `PRISM_PASSWORD` | ... | PC credentials |
| `CONTROL_PLANE_VIP` | `10.0.0.201` | kube-vip VIP |
| `LB_RANGE_START` / `LB_RANGE_END` | ... | MetalLB range |
| `NKP_IMAGE_NAME` | `nkp-rocky-9.7-1.35.2` | NKP node image |
| `KUBERNETES_VERSION` | `v1.35.2` | Kubernetes version |
| `NKP_VERSION` | `v2.18.0` | NKP version |
