# base/ — generic templates

Immutable, cluster-agnostic templates. **No IPs, DNs, secrets, or cluster-specific values** —
those use `${VAR}` placeholders and are set in the overlay (or pinned with a JSON patch).

```
base/cluster-apps/identity-access/dex/
├── kustomization.yaml                 # resources: connectors/ad/ + VG + secret
├── connectors/
│   ├── ad/                            # ✅ DEFAULT (type: ldap = Active Directory)
│   ├── okta/                          # Okta (type: oidc)
│   └── README.md
├── virtual-group.yaml                 # VirtualGroup/admins (maps an AD group → NKP)
├── clusterrolebinding.yaml            # group → cluster-admin
├── secrets/
│   ├── ldap-bind/                     # Secret/ldap-bind (bind password, placeholder)
│   └── okta-client/                   # Secret/okta-client (client-id/client-secret, placeholder)
└── README.md                          # full connector reference (every option)
```

Dex has **no `AppDeployment`** here — Kommander ships and runs Dex; we only ship the CRs.
Field-by-field reference: `cluster-apps/identity-access/dex/README.md`.
