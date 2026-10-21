# Secret Value Reverted After kubectl apply

## Symptom

You manually `kubectl apply` a Secret, then it reverts to the previous value shortly after.

## Cause

The Secret is managed by **ESO (External Secrets Operator)** from a backend (Vault, AWS Secrets
Manager, etc.). ESO reconciles the Secret's value from the backend, overwriting any manual changes.

## Diagnosis

1. Check if the Secret has an `ExternalSecret` referencing it:
   ```bash
   kubectl get externalsecret -n kommander
   ```
2. Check the ExternalSecret's `secretStoreRef` and `target.name`.

## Fix

Change the value in the **backend** (e.g., Vault KV store), not in kubectl. Then force-sync:
```bash
kubectl annotate externalsecret <name> -n kommander esb.syn.tools/reconcile= --force
```

## Prevention

- Document which secrets are ESO-managed in the overlay documentation.
- Use `secret-patch.yaml` with `${VAR}` for Flux-substituted secrets (not manual kubectl apply).
- Add a comment in `secret-patch.yaml.example` noting ESO management.
