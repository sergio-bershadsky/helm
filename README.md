# Helm Charts

Personal Helm chart collection published as OCI artifacts to `ghcr.io/bershadsky/charts`.

## Charts

| Chart | Description |
|-------|-------------|
| [odoo](charts/odoo/) | Production-ready Odoo with PostgreSQL, S3, and optional frontend |

## Usage

```bash
helm install my-release oci://ghcr.io/bershadsky/charts/odoo --version 0.2.0
```

## Development

```bash
# Lint
helm dependency update charts/odoo
helm lint charts/odoo

# Template
helm template test charts/odoo \
  --set postgresql.auth.password=test \
  --set minio.auth.rootPassword=test
```
