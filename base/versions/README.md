# Centralized version registry

This ConfigMap holds the canonical version for every NKP ClusterApp in this repository.
The overlay's `kustomization.yaml` uses kustomize `replacements` to inject these versions
into AppDeployment `spec.appRef.name` fields.

## Adding a new version

1. Add the version key to this ConfigMap: `fluent-bit: "fluent-bit-0.57.2"`
2. Add a `replacements` entry in the overlay's `kustomization.yaml` (see `docs/specs/version-management.md`)

## Current versions

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-versions
  namespace: kommander
data:
  # --- AppDeployment versions (NKP ClusterApps) ---
  fluent-bit: "fluent-bit-0.57.2"
  kube-prometheus-stack: "kube-prometheus-stack-82.13.6"
  grafana-loki-v3: "grafana-loki-v3-3.6.7"
  rook-ceph-cluster: "rook-ceph-cluster-1.19.6"
  velero: "velero-12.0.0"
  external-dns: "external-dns-10.20.0"

  # --- HelmRelease versions (third-party charts) ---
  vault-operator: "1.24.1"
```
