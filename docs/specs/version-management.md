# Spec — Version management

Versions for AppDeployments are centralized in `base/versions/app-versions.configmap.yaml`.
The overlay's `kustomization.yaml` uses kustomize `replacements` to inject these versions
into AppDeployment `spec.appRef.name` fields.

## Adding a new app version

1. Add the version to `base/versions/app-versions.configmap.yaml`:
   ```yaml
   data:
     <app>: "<app>-<version>"
   ```

2. Add a replacement in `overlay/.../cluster-apps/kustomization.yaml`:
   ```yaml
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

## How it works

1. The ConfigMap in `base/versions/` is included in the base Kustomization.
2. The overlay's `replacements` transformer reads the ConfigMap and patches the AppDeployment.
3. The result is that `spec.appRef.name` is set to the value from the ConfigMap.

## HelmRelease versions

HelmRelease versions are NOT centralized. They are set in the overlay JSON patch:
```yaml
# overlay/.../patches/helm-releases/<app>/helmrelease-patch.yaml
- op: replace
  path: /spec/chart/spec/version
  value: "${<APP>_CHART_VERSION}"
```

This is because Helm chart versions come from the HelmRepository (which may be a different
source than NKP ClusterApps).
