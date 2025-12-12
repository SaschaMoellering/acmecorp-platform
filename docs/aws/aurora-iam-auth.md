# Aurora PostgreSQL IAM Authentication (Orders & Catalog)

This guide covers enabling IAM auth on Aurora Postgres and wiring Kubernetes workloads (orders-service, catalog-service) via EKS Pod Identity.

## 1. Enable IAM Authentication on Aurora

1. Open the cluster settings in the Amazon RDS console.
2. Edit the cluster and enable **IAM DB authentication**.
3. Ensure the cluster uses an engine that supports IAM (Aurora PostgreSQL 13+).
4. Apply changes; note that enabling IAM auth requires a cluster reboot/maintenance window.

## 2. Create IAM-Enabled DB User

Connect to the database as a superuser (e.g., `rds_superuser`) and run:

```sql
CREATE USER iam_user WITH LOGIN;
GRANT rds_iam TO iam_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO iam_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO iam_user;
```

Change `iam_user` to your desired username; ensure it matches `ACMECORP_PG_USER`.

## 3. IAM Policy for `rds-db:connect`

The workload needs permission to call `rds-db:connect`. Use the example policy in `docs/aws/iam/policy-rds-db-connect.json` and fill in:

- `ACCOUNT_ID` – your AWS account number
- `REGION` – region of the Aurora cluster
- `DB_RESOURCE_ID` – obtained via:
  ```bash
  aws rds describe-db-instances --filters Name=db-instance-id,Values=<instance-id> \
    --query "DBInstances[0].DbInstanceArn" --output text
  ```
  The `db-resource-id` is usually `<cluster-id>:<db-instance-id>`.
- `DB_USER` – the IAM-enabled user (e.g., `iam_user`)

Attach the policy to the IAM role that Pod Identity will expose to the Pod.

## 4. EKS Pod Identity Association

Assuming you use AWS Controllers for Kubernetes (ACK) or OIDC-based Pod Identity (Kubernetes Service Account linked to IAM role), create an IAM role with the policy above and map it to a K8s service account:

1. Create a Kubernetes service account (e.g., `orders-service-iam`).
2. Annotate it for the AWS IAM controller you use.
3. Apply the `docs/aws/pod-identity/*.yaml` manifest that references the example `AWSRole`.

## 5. Helm / Env Var Requirements

When IAM auth is enabled (via `acmecorp.postgres.iam-auth.enabled=true`), set the following env vars in the Helm values for each service:

- `ACMECORP_PG_IAM_AUTH=true`
- `ACMECORP_PG_HOST` – Aurora endpoint (cluster writer endpoint)
- `ACMECORP_PG_PORT` – typically `5432`
- `ACMECORP_PG_DB` – database name (default `acmecorp`)
- `ACMECORP_PG_USER` – IAM-enabled user
- `AWS_REGION` or override `ACMECORP_PG_REGION`

The chart will skip `DB_PASSWORD` when IAM auth is active. Provide a Kubernetes Secret for any other credentials (e.g., RabbitMQ) as usual.

## 6. Observability & Rotation Notes

- The IAM token TTL is 15 minutes, so we limit connection max lifetime (orders: 9m, catalog: 9m) and rely on the token suppliers to refresh per connection.
- Monitor RDS logs for denied connections if the role lacks `rds-db:connect`.
