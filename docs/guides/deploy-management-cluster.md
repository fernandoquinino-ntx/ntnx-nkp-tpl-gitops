# Guide — Deploying a Management Cluster

This guide walks through deploying a self-managed NKP management cluster using manifests.

## Prerequisites

- Nutanix AHV cluster with Prism Central
- NKP node image uploaded to Prism Central
- Bastion host with SSH access to the AHV cluster
- Management cluster kubeconfig (from kind bootstrap)

## Step 1: Prepare the kind bootstrap cluster

```bash
# On your workstation, run:
nkp create bootstrap --kubeconfig mgmt-kubeconfig --timeout 10m
```

This creates a local kind cluster.

## Step 2: Apply the management cluster manifests

```bash
export KUBECONFIG=mgmt-kubeconfig

# Apply the management cluster manifests
kubectl apply -k base/management-cluster/
```

This creates:
- `NKPCluster` CR with `kommander.d2iq.io/host: "true"` label
- 5 credential secrets
- `kommander-bootstrap-configuration` ConfigMap

## Step 3: Wait for provisioning

```bash
# Wait for CAPI machines to be Ready
kubectl -n kommander wait --for=jsonpath='{.status.phase}'=Provisioned \
  cluster/mgmt-a --timeout=45m
```

## Step 4: Extract the workload kubeconfig

```bash
nkp get kubeconfig -c mgmt-a -n kommander --kubeconfig mgmt-kubeconfig > workload-kubeconfig
```

## Step 5: Pivot CAPI to the workload cluster

```bash
# Deploy CAPI components to the workload cluster
nkp create capi-components --kubeconfig workload-kubeconfig

# Move CAPI resources from kind → workload cluster
nkp move capi-resources \
  --from-kubeconfig mgmt-kubeconfig \
  --to-kubeconfig workload-kubeconfig \
  --namespace kommander \
  --to-nkp-namespace kommander

# Delete the kind bootstrap cluster
nkp delete bootstrap --kubeconfig mgmt-kubeconfig
```

## Step 6: Install Kommander

```bash
# Extract the installer config
kubectl -n kommander get configmap kommander-installer-config \
  -o jsonpath='{.data.kommander\.yaml}' > kommander.yaml

# Install Kommander
nkp install kommander \
  --installer-config kommander.yaml \
  --kubeconfig workload-kubeconfig \
  --wait --wait-timeout 30m

# Patch OCIRepositories for Docker Hub auth
kubectl patch ocirepository dockerhub \
  --type merge -p '{"spec":{"secretRef":{"name":"dockerhub-auth"}}}' \
  -n kommander
```

## Step 7: Apply the overlay manifests

```bash
export KUBECONFIG=workload-kubeconfig

# Apply the mgmt overlay
kubectl apply -k overlay/clusters/reference/mgmt
```

---

## Variable Reference

| Variable | Example | Description |
|---|---|---|
| `MGMT_CLUSTER_NAME` | `mgmt-a` | Cluster name |
| `MGMT_CLUSTER_NAMESPACE` | `kommander` | Namespace |
| `PRISM_ENDPOINT` | `10.0.0.100` | Prism Central IP/FQDN |
| `PRISM_USERNAME` | `admin@local` | PC admin user |
| `PRISM_PASSWORD` | `...` | PC password |
| `PRISM_UUID` | `uuid-...` | PC UUID (immutable) |
| `CONTROL_PLANE_VIP` | `10.0.0.200` | kube-vip VIP |
| `LB_RANGE_START` | `10.0.0.250` | MetalLB range start |
| `LB_RANGE_END` | `10.0.0.255` | MetalLB range end |
| `NKP_IMAGE_NAME` | `nkp-rocky-9.7-1.35.2` | NKP node image |
| `KUBERNETES_VERSION` | `v1.35.2` | Kubernetes version |
| `NKP_VERSION` | `v2.18.0` | NKP version |
| `DOCKERHUB_USERNAME` | `...` | Docker Hub user |
| `DOCKERHUB_PASSWORD` | `...` | Docker Hub pass |
