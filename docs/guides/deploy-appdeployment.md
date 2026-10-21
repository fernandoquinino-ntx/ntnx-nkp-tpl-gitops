# Guide — Deploying AppDeployments

This guide walks through adding a new NKP ClusterApp (monitoring, logging, storage, backup)
to the template using the AppDeployment model.

## Step 1: Create the base directory

```bash
mkdir -p base/appdeployments/<app>/configs
```

## Step 2: Create the AppDeployment template

```yaml
# base/appdeployments/<app>/<app>.appdeployment.yaml
apiVersion: apps.kommander.d2iq.io/v1alpha3
kind: AppDeployment
metadata:
  name: <app>
  namespace: kommander
spec:
  appRef:
    appID: <catalog-app-id>
    kind: ClusterApp
    name: "${<APP>_APP_REF}"          # Version from centralized versions ConfigMap
    namespace: kommander
  configOverrides:
    name: "<app>-override"
  clusterConfigOverrides:
    - clusterSelector:
        matchExpressions:
          - key: kommander.d2iq.io/cluster-name
            operator: In
            values:
              - "${MGMT_CLUSTER_NAME}"
      configMapName: "<app>-override"
```

## Step 3: Create the override ConfigMap

```yaml
# base/appdeployments/<app>/configs/<app>-override.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <app>-override
  namespace: kommander
data:
  values.yaml: |
    # Helm values with ${VAR} placeholders
    image:
      tag: "${<APP>_IMAGE_TAG}"
    someSetting: "${<APP>_SOME_SETTING}"
```

## Step 4: Create the kustomization.yaml

```yaml
# base/appdeployments/<app>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - configs/<app>-override.yaml    # ← ConfigMap FIRST
  - <app>.appdeployment.yaml       # ← AppDeployment SECOND
```

## Step 5: Add the version to the centralized registry

```yaml
# base/versions/app-versions.configmap.yaml
data:
  <app>: "<app>-<version>"
```

## Step 6: Add the replacement in the overlay

```yaml
# overlay/.../cluster-apps/kustomization.yaml
replacements:
  - source:
      kind: ConfigMap
      name: app-versions
      fieldPath: data.<app>
    targets:
      - select:
          kind: AppDeployment
          name: <app>
        fieldPaths:
          - spec.appRef.name
```

## Step 7: Create the overlay Component

```bash
mkdir -p overlay/clusters/reference/cluster-apps/patches/appdeployments/<app>
```

```yaml
# overlay/.../patches/appdeployments/<app>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
resources:
  - ../../../../../../../base/appdeployments/<app>
patches:
  - path: appdeployment-patch.yaml
    target: { group: apps.kommander.d2iq.io, version: v1alpha3, kind: AppDeployment, name: <app> }
  - path: config-patch.yaml
    target: { version: v1, kind: ConfigMap, name: <app>-override }
```

## Step 8: Create the JSON patches

```yaml
# overlay/.../patches/appdeployments/<app>/appdeployment-patch.yaml
- op: replace
  path: /spec/appRef/name
  value: "${<APP>_APP_REF}"
- op: replace
  path: /spec/clusterConfigOverrides/0/clusterSelector/matchExpressions/0/values/0
  value: "${MGMT_CLUSTER_NAME}"
```

```yaml
# overlay/.../patches/appdeployments/<app>/config-patch.yaml
- op: replace
  path: /data/values.yaml
  value: |
    image:
      tag: "${<APP>_IMAGE_TAG}"
    someSetting: "${<APP>_SOME_SETTING}"
```

## Step 9: Add variables to cluster-vars.yaml and .env.example

```yaml
# overlay/.../cluster-vars.yaml
data:
  <APP>_APP_REF: "<app>-<version>"
  <APP>_IMAGE_TAG: "<tag>"
  MGMT_CLUSTER_NAME: "mgmt-a"
```

## Step 10: Register in the aggregator

```yaml
# overlay/.../cluster-apps/kustomization.yaml
components:
  - patches/appdeployments/<app>    # ← add this line
```

## Step 11: Validate

```bash
scripts/validate-overlay.sh reference
scripts/render.sh reference
```
