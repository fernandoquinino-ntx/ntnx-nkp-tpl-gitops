# Dex (identity-access) — complete Connector guide

Dex is the identity broker that **ships with NKP/Kommander**. You do **not** deploy it; you
**configure** it by creating `Connector` custom resources in the `kommander` namespace.

## Directory structure

```
base/cluster-apps/identity-access/dex/
├── kustomization.yaml                 # SHARED RBAC only (virtual-group + clusterrolebinding)
├── virtual-group.yaml                 # VirtualGroup/admins — maps an IdP group → NKP group
├── clusterrolebinding.yaml            # group → cluster-admin
├── connectors/
│   ├── ad/                            # ✅ AD (type: ldap) — added by overlay provider `providers/ad`
│   │   ├── kustomization.yaml
│   │   └── connector.yaml
│   └── okta/                          # Okta (type: oidc) — added by `providers/okta`
│       ├── kustomization.yaml
│       └── connector.yaml
└── secrets/
    ├── ldap-bind/                     # Secret/ldap-bind (AD bind password)
    │   ├── kustomization.yaml
    │   └── secret.yaml
    └── okta-client/                   # Secret/okta-client (Okta client-id/client-secret)
        ├── kustomization.yaml
        └── secret.yaml
```

## Switching providers

The cluster's top Component selects **one provider** via `components:`:

```yaml
# overlay/clusters/<cluster>/cluster-apps/patches/identity-access/dex/kustomization.yaml
components:
  - providers/ad    # ← AD/LDAP (default)
  # OR
  - providers/okta  # ← Okta/OIDC
```

## How to use (TL;DR)

1. **Pick a connector.** Default = AD LDAP (`connectors/ad/`).
2. **Set the `${VAR}` values** for the cluster in `overlay/clusters/<cluster>/cluster-vars.yaml`.
3. **Provide the bind password** (never in git): a `Secret` key `password`, or the
   `${VAR}` fed from `cluster-secrets` / Vault.
4. **Map groups to roles** with `VirtualGroup` + RBAC (already configured in base).
5. **Build & apply** the parent overlay: `kubectl apply -k overlay/clusters/<cluster>/cluster-apps`.
   Validate with `scripts/validate-overlay.sh <cluster>`.

## Connector types

The NKP Dex CRD supports exactly four connector types:

| Type | Description | Base file |
|---|---|---|
| `ldap` | Active Directory (default) | `connectors/ad/` |
| `oidc` | OpenID Connect (Okta, etc.) | `connectors/okta/` |
| `saml` | SAML 2.0 | (add manually) |
| `github` | GitHub / GitHub Enterprise | (add manually) |

## Override recipes

### Pin AD values (JSON patch)
```yaml
- op: replace
  path: /spec/ldap/host
  value: "dc01.ad.example.local:636"
- op: replace
  path: /spec/ldap/bindDN
  value: "CN=svc-nkp,CN=Users,DC=ad,DC=example,DC=local"
```

### Trust internal CA instead of skipping verify
```yaml
- op: replace
  path: /spec/ldap/insecureSkipVerify
  value: false
- op: add
  path: /spec/ldap/rootCASecretRef
  value: { name: "ad-root-ca" }
```

### Use StartTLS on :389
```yaml
- op: replace
  path: /spec/ldap/startTLS
  value: true
- op: replace
  path: /spec/ldap/insecureNoSSL
  value: false
```

## Gotchas

- **`insecureNoSSL: true` + `startTLS: true` is broken.** Use LDAPS `:636` or StartTLS with `insecureNoSSL: false`.
- **`rootCAData` is not in the CRD** — trust a CA with `rootCASecretRef` (key `tls.crt`) or set `insecureSkipVerify: true` (lab only).
- **Secret keys are fixed**: LDAP `bindSecretRef` → `password`; OIDC/GitHub `clientSecretRef` → `client-id` + `client-secret`.
- **Group claim form**: `oidc:<groupSearch.nameAttr value>` — that exact string is what `VirtualGroup`/RBAC must reference.
- **Empty `groupSearch.baseDN` disables groups** — no groups ⇒ no role mappings.

See [ntnx-nkp-tpl-repo.md](../../ntnx-nkp-tpl-repo.md) for complete standards.
