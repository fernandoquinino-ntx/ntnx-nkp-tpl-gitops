# AppDeployment Version Mismatch After Upgrade

## Symptom

An AppDeployment is running an older version than expected. After updating the version in
`base/versions/app-versions.configmap.yaml`, the change doesn't take effect.

## Cause

1. The kustomize `replacements` entry is missing or misconfigured in the overlay.
2. The ConfigMap key doesn't match the replacement `fieldPath`.
3. Flux hasn't reconciled yet (check `interval`).

## Diagnosis

1. Check the replacement in `overlay/.../cluster-apps/kustomization.yaml`:
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
2. Verify the ConfigMap key exists:
   ```bash
   kubectl get configmap app-versions -n kommander -o jsonpath='{.data.<app>}'
   ```
3. Render locally to see if the replacement works:
   ```bash
   scripts/render.sh reference
   grep appRef.name /tmp/ntnx-render/reference/...
   ```

## Fix

1. Add or fix the replacement in the overlay's `kustomization.yaml`.
2. Commit and push — Flux will reconcile on the next interval.
3. Force reconcile if needed:
   ```bash
   kubectl annotate kustomization cluster-apps -n kommander-flkux \
     fluxcd.io/sync-gc-mark="$(date +%s)" --force
   ```

## Prevention

- Always add the replacement when adding a new version to the ConfigMap.
- Run `scripts/validate-overlay.sh reference` before committing.
- Document the version upgrade process in the repo README.
