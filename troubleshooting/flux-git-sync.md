# Flux Kustomization Stuck: "waiting for first git fetch"

## Symptom

`kubectl get kustomization -n kommander-flux` shows:
```
NAME     AGE   READY   STATUS
dex      5m    False   waiting for first git fetch
```

## Cause

The Flux `GitRepository` source is not yet available, or authentication is misconfigured.

## Diagnosis

1. Check the GitRepository status:
   ```bash
   kubectl get gitrepository -n kommander-flux
   ```
2. Check for errors:
   ```bash
   kubectl describe gitrepository ntnx-nkp-tpl-gitops -n kommander-flux
   ```
3. Common issues:
   - `url` in `gitrepository.yaml` points to wrong repo
   - `secretRef` (github-app-auth) doesn't exist or has invalid credentials
   - Network/firewall blocks access to the git host

## Fix

1. Verify the `url` in `flux-system/gitrepository.yaml` points to the correct repository.
2. Ensure the `github-app-auth` Secret exists in `kommander-flux` namespace.
3. Check that the GitHub App (or token) has read access to the repository.
4. Wait a few minutes — Flux may take time to clone a large repo.

## Prevention

- Test the `gitrepository.yaml` URL and credentials before deploying.
- Include `gitrepository.yaml` and `01-cluster-apps.yaml` in the overlay documentation.
