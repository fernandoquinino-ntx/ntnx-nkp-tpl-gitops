# Guide — Deploying HelmReleases

This guide walks through adding a third-party Helm chart to the template using the HelmRelease model.

## Step 1: Create the base directory

```bash
mkdir -p base/helm-releases/<app>
```

## Step 2: Create the HelmRepository template

```yaml
# base/helm-releases/<app>/helmrepository.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: <app>
  namespace: <namespace>
spec:
  type: oci                              # or "generic" for HTTP Helm repos
  interval: 5m
  url: "${<APP>_HELM_REPO_URL}"
```

## Step 3: Create the HelmRelease template

```yaml
# base/helm-releases/<app>/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: <app>
  namespace: <namespace>
spec:
  interval: 5m
  chart:
    spec:
      chart: <chart-name>
      version: "${<APP>_CHART_VERSION}"
      sourceRef:
        kind: HelmRepository
        name: <app>
        namespace: <namespace>
      interval: 5m
  install:
    createNamespace: true
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
  rollback:
    enabled: true
  values:
    image:
      tag: "${<APP>_IMAGE_TAG}"
    someSetting: "${<APP>_SOME_SETTING}"
```

## Step 4: Create the kustomization.yaml

```yaml
# base/helm-releases/<app>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - helmrepository.yaml
  - helmrelease.yaml
```

## Step 5: Create the overlay Component

```bash
mkdir -p overlay/clusters/reference/cluster-apps/patches/helm-releases/<app>
```

```yaml
# overlay/.../patches/helm-releases/<app>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
resources:
  - ../../../../../../../base/helm-releases/<app>
patches:
  - path: helmrepository-patch.yaml
    target: { group: source.toolkit.fluxcd.io, version: v1, kind: HelmRepository, name: <app> }
  - path: helmrelease-patch.yaml
    target: { group: helm.toolkit.fluxcd.io, version: v2, kind: HelmRelease, name: <app> }
```

## Step 6: Create the JSON patches

```yaml
# overlay/.../patches/helm-releases/<app>/helmrepository-patch.yaml
- op: replace
  path: /spec/url
  value: "${<APP>_HELM_REPO_URL}"
```

```yaml
# overlay/.../patches/helm-releases/<app>/helmrelease-patch.yaml
- op: replace
  path: /spec/chart/spec/version
  value: "${<APP>_CHART_VERSION}"
- op: replace
  path: /spec/values/image/tag
  value: "${<APP>_IMAGE_TAG}"
```

## Step 7: Add variables to cluster-vars.yaml and .env.example

```yaml
# overlay/.../cluster-vars.yaml
data:
  <APP>_HELM_REPO_URL: "oci://ghcr.io/bank-vaults/helm-charts"
  <APP>_CHART_VERSION: "1.24.1"
  <APP>_IMAGE_TAG: "1.24.1"
```

## Step 8: Register in the aggregator

```yaml
# overlay/.../cluster-apps/kustomization.yaml
components:
  - patches/helm-releases/<app>    # ← add this line
```

## Step 9: Validate

```bash
scripts/validate-overlay.sh reference
scripts/render.sh reference
```
