# Undeclared ${VAR} Placeholder

## Symptom

`scripts/validate-overlay.sh reference` fails with:
```
FAIL: undeclared ${VAR} placeholders in the build:
    SOMETHING_UNSURE
    -> declare them in overlay/clusters/reference/cluster-vars.yaml (non-secret) or .env.example / cluster-secrets (secret).
```

## Cause

A `${VAR}` placeholder exists in a manifest but is not declared in `cluster-vars.yaml` or `.env.example`.

## Diagnosis

1. Run `scripts/validate-overlay.sh reference` — it lists the undeclared vars.
2. Check `cluster-vars.yaml` and `.env.example` for the missing variable.

## Fix

Add the missing variable to `cluster-vars.yaml` (non-secret) or `.env.example` (for local rendering).
For secrets, also add to `cluster-secrets` Secret (referenced in Flux `postBuild.substituteFrom`).

## Prevention

- Always declare `${VAR}` in `cluster-vars.yaml` when adding a new placeholder to `base/`.
- Run `scripts/validate-overlay.sh reference` before committing changes.
