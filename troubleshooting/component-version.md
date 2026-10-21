# kustomize build Fails: "no matches for kind Component"

## Symptom

`kustomize build` or `kubectl kustomize` fails with:
```
no matches for kind Component in version kustomize.config.k8s.io/v1alpha1
```

## Cause

Kustomize Components (`kind: Component`) require a **newer version** of kustomize (≥ 4.5.5) or
kubectl (≥ 1.21). Older versions don't recognize `v1alpha1` Component.

## Diagnosis

1. Check kustomize version: `kustomize version`
2. Check kubectl version: `kubectl version --client`

If kustomize < 4.5.5 or kubectl < 1.21, the Component API is not supported.

## Fix

Upgrade kustomize or kubectl to a version that supports `kind: Component` (v1alpha1).

For `scripts/validate-overlay.sh` and `scripts/render.sh`, the script tries `kubectl kustomize`
as a fallback if `kustomize` is not available.

## Prevention

Document the minimum kustomize/kubectl versions in the README. Pin versions in CI/CD.
