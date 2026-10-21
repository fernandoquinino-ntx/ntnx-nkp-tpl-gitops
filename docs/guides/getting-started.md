# Guide — Getting Started with ntnx-nkp-tpl-gitops

This guide walks you through creating a new NKP application repository from the template.

## Step 1: Fork or copy the template

```bash
# Option A: Fork on GitHub
gh repo fork fernandoquinino-ntx/ntnx-nkp-tpl-gitops my-app-repo

# Option B: Copy locally
cp -r /workspaces/ntnx-nkp-tpl-gitops ~/my-app-repo
cd ~/my-app-repo
git init
```

## Step 2: Understand the structure

Read [ntnx-nkp-tpl-gitops.md](../../ntnx-nkp-tpl-gitops.md) for the complete reference.

Key directories:
- `base/cluster-apps/` — generic templates
- `overlay/clusters/reference/` — reference cluster overlay
- `scripts/` — validation and rendering tools

## Step 3: Customize for your application

1. Replace the `identity-access/dex` app with your application under `base/cluster-apps/<category>/<app>/`.
2. Update all `${VAR}` placeholders to match your application's configuration.
3. Update `cluster-vars.yaml` and `.env.example` with your variables.
4. Update JSON patches in the overlay to target your resources.

## Step 4: Validate

```bash
scripts/validate-overlay.sh reference
scripts/render.sh reference
```

## Step 5: Create a real cluster overlay

```bash
cp -r overlay/clusters/reference overlay/clusters/production
# Edit production values...
```

## Step 6: Deploy

```bash
kubectl apply -k overlay/clusters/production/cluster-apps
```
