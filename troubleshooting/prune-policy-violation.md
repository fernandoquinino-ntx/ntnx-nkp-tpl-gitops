# prune: true Deleted a Platform Object

## Symptom

Flux deleted a platform object (License, Connector, VirtualGroup) that was supposed to be
protected. The object is missing from the cluster.

## Cause

`prune: true` was set on the Flux Kustomization, and the platform object was either:
1. Not included in the current manifest (removed from `base/` or overlay)
2. Listed after an app resource in the Kustomization, causing ordering issues

## Diagnosis

1. Check the Flux Kustomization:
   ```bash
   kubectl get kustomization <name> -n kommander-flux -o yaml
   ```
2. Look for `prune: true` — platform objects should have `prune: false`.
3. Check if the object was removed from the manifest.

## Fix

1. **Immediate:** Re-apply the platform object manifest:
   ```bash
   kubectl apply -f base/custom-crds/<app>/<resource>.yaml
   ```
2. **Permanent:** Change the prune policy:
   - For platform-only repos: `prune: false`
   - For mixed repos: split into separate Flux Kustomizations (one for platform, one for apps)

## Prevention

- Follow the prune policy table in [PRACTICES.md](../PRACTICES.md) Section 9.1.
- Run `scripts/verify-prune.sh reference` before committing.
- ADR 0003 documents the prune policy decision.
