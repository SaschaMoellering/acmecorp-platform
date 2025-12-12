# Orders Service IAM Auth

The orders service supports connecting to Aurora PostgreSQL using IAM authentication tokens instead of static passwords.

## Enabling IAM Auth

Set the following environment variables in the EKS Pod (Helm values will need to export them when `acmecorp.postgres.iam-auth.enabled=true`):

- `ACMECORP_PG_IAM_AUTH=true`
- `ACMECORP_PG_HOST` – Aurora endpoint
- `ACMECORP_PG_PORT` – 5432 (default)
- `ACMECORP_PG_DB` – database name (e.g., `acmecorp`)
- `ACMECORP_PG_USER` – IAM-enabled database user
- `ACMECORP_PG_REGION` or rely on `AWS_REGION`

When IAM auth is enabled, the service generates authentication tokens via the AWS SDK (default credential provider chain) and refreshes connections before the token expires. For local development keep `ACMECORP_PG_IAM_AUTH=false` so the standard `spring.datasource.*` settings with `DB_USERNAME`/`DB_PASSWORD` still work.
