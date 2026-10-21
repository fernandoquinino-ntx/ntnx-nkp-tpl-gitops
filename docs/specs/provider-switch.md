# Spec — Provider switch

The provider switch pattern allows swapping implementations (e.g., AD ↔ Okta) by changing
one line in the overlay Component.

## How it works

1. **Base layer** (`base/cluster-apps/<cat>/<app>/providers/<name>/`): Each provider has its
   own directory with a `kustomization.yaml` and resource files. All providers are inert until
   referenced.

2. **Overlay Component** (`overlay/.../patches/<cat>/<app>/kustomization.yaml`): The top Component
   selects ONE provider via `components:`:
   ```yaml
   components:
     - providers/ad    # ← default
     # OR
     - providers/okta  # ← switch
   ```

3. **Provider patch Component** (`overlay/.../providers/<name>/kustomization.yaml`): Each provider
   patch Component references its base provider, adds JSON patches, and includes the secret patch.

## Switching providers

```bash
# 1. Edit the overlay Component
# overlay/clusters/<cluster>/cluster-apps/patches/<cat>/<app>/kustomization.yaml
# Change: components: [providers/ad] → components: [providers/okta]

# 2. Update cluster-vars.yaml with provider-specific variables

# 3. Update .env.example with provider-specific variables

# 4. Validate
scripts/validate-overlay.sh <cluster>

# 5. Apply
kubectl apply -k overlay/clusters/<cluster>/cluster-apps
```

## Adding a new provider

1. Create `base/cluster-apps/<cat>/<app>/providers/<new>/` with `kustomization.yaml` and resource.
2. Create `overlay/.../providers/<new>/kustomization.yaml` referencing the base.
3. Create `overlay/.../providers/<new>/connector.yaml` (JSON patches).
4. Create `overlay/.../providers/<new>/secret-patch.yaml.example`.
5. Update the top Component's `components:` to include the new provider.
