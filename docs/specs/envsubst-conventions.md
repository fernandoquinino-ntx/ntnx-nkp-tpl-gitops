# Spec — envsubst conventions

Variables follow these conventions:

## Naming

- UPPERCASE with underscores: `FLUENT_BIT_IMAGE_TAG`, `VAULT_ADDR`, `DEX_LDAP_HOST`
- Prefix with app/category: `FLUENT_BIT_`, `VAULT_`, `DEX_`, `OKTA_`
- Descriptive: `<APP>_<FIELD>` or `<CATEGORY>_<FIELD>`

## Declaration

| Type | Where declared | Example |
|---|---|---|
| Non-secret | `overlay/clusters/<cluster>/cluster-vars.yaml` (ConfigMap) | `FLUENT_BIT_IMAGE_TAG: "3.1.6"` |
| Secret | `overlay/clusters/<cluster>/cluster-secrets` (Secret) | `FLUENT_BIT_API_KEY: "${FLUENT_BIT_API_KEY}"` |
| Both | `overlay/clusters/<cluster>/.env.example` | `FLUENT_BIT_IMAGE_TAG="3.1.6"` |

## Usage in manifests

- Use `${VAR}` syntax (not `$VAR` or `{{ .Vars.VAR }}`)
- Quote string values: `"${VAR}"`
- Boolean values: `"true"` or `"false"` (quoted, as YAML strings)

## Validation

`scripts/validate-overlay.sh` checks that every `${VAR}` in the build output is declared
in `cluster-vars.yaml` or `.env.example`. An undeclared variable is a bug.
