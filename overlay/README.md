# overlay/ — per-cluster overrides

This directory contains overlays for specific clusters. **Never edit `base/` for a cluster** —
always create or modify overlays here.

## The `reference` cluster

`overlay/clusters/reference/` is a **reference** (not deployed). It ships with example values
that demonstrate the structure. To create a real cluster overlay:

```bash
cp -r overlay/clusters/reference overlay/clusters/<your-cluster>
```

Then:
1. Edit `cluster-vars.yaml` with your cluster's values (or use `${VAR}` for Flux).
2. Copy `.env.example` → `.env` and fill in real values for local rendering.
3. For each provider, copy `secret-patch.yaml.example` → `secret-patch.yaml` (gitignored).
4. If using a non-default provider, change the `components:` line in the overlay Component.

See [ntnx-nkp-tpl-repo.md](../../ntnx-nkp-tpl-repo.md) for the complete overlay model.
