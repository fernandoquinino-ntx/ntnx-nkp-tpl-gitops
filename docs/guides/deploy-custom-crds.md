# Guide — Deploying Custom CRDs

This guide walks through adding a custom CRD (Dex Connector, MetalLB, License, etc.) to the template.
Use this model when the resource is a CR but not an AppDeployment or HelmRelease.

## Step 1: Create the base directory

```bash
mkdir -p base/custom-crds/<app>
```

## Step 2: Create the CR template

```yaml
# base/custom-crds/<app>/<resource>.yaml
apiVersion: <api-group>/<version>
kind: <Kind>
metadata:
  name: <stable-name>
  namespace: kommander
spec:
  field: "${<APP>_FIELD}"
```

## Step 3: Create the kustomization.yaml

```yaml
# base/custom-crds/<app>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - <resource>.yaml
```

## Step 4: (Optional) Create provider implementations

If you need swappable implementations (e.g., AD vs Okta for Dex):

```bash
mkdir -p base/custom-crds/<app>/providers/<provider>
```

```yaml
# base/custom-crds/<app>/providers/<provider>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: [resource.yaml]
```

## Step 5: Create the overlay Component

```bash
mkdir -p overlay/clusters/reference/cluster-apps/patches/custom-crds/<app>/providers/<provider>
```

```yaml
# overlay/.../patches/custom-crds/<app>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
resources:
  - ../../../../../../../base/custom-crds/<app>
components:
  - providers/<default-provider>    # ← switch to providers/<other>
```

```yaml
# overlay/.../patches/custom-crds/<app>/providers/<provider>/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
resources:
  - ../../../../../../../../../base/custom-crds/<app>/providers/<provider>
patches:
  - path: patch.yaml
    target: { group: <api-group>, version: <version>, kind: <Kind>, name: <name> }
```

## Step 6: Create the JSON patch

```yaml
# overlay/.../patches/custom-crds/<app>/providers/<provider>/patch.yaml
- op: replace
  path: /spec/<field>
  value: "${<APP>_FIELD}"
```

## Step 7: Add variables to cluster-vars.yaml and .env.example

```yaml
# overlay/.../cluster-vars.yaml
data:
  <APP>_FIELD: "concrete-value-or-${VAR}"
```

## Step 8: Register in the aggregator

```yaml
# overlay/.../cluster-apps/kustomization.yaml
components:
  - patches/custom-crds/<app>    # ← add this line
```

## Step 9: Validate

```bash
scripts/validate-overlay.sh reference
scripts/render.sh reference
```
