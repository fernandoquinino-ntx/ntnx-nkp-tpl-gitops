# Spec — envsubst conventions

Variables follow these conventions:

## Naming

- UPPERCASE with underscores: `DEX_LDAP_HOST`, `OKTA_ISSUER`
- Prefix with app/category: `DEX_`, `OKTA_`, `NETWORK_`
- Descriptive: `<APP>_<FIELD>` or `<CATEGORY>_<FIELD>`

## Declaration

- Non-secret: `overlay/clusters/<cluster>/cluster-vars.yaml` (ConfigMap)
- Secret: `overlay/clusters/<cluster>/cluster-secrets` (Secret, referenced in Flux)
- Both: `overlay/clusters/<cluster>/.env.example` (for local rendering)

## Usage in manifests

- Use `${VAR}` syntax (not `$VAR` or `{{ .Vars.VAR }}`)
- Quote string values: `"${VAR}"`
- Boolean values: `"true"` or `"false"` (quoted, as YAML strings)

## Validation

`scripts/validate-overlay.sh` checks that every `${VAR}` in the build output is declared
in `cluster-vars.yaml` or `.env.example`. An undeclared variable is a bug.
