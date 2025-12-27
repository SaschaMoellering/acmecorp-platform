# AcmeCorp Platform - AWS Infrastructure

Production-ready Terraform infrastructure for AcmeCorp Platform following AWS Well-Architected Framework best practices.

## Architecture Overview

### Core Components

- **EKS Auto Mode**: Serverless Kubernetes with mixed architecture (Intel + Graviton)
- **Aurora PostgreSQL**: Multi-AZ with IAM authentication
- **VPC**: 3-AZ setup with public/private subnets
- **S3 + CloudFront**: Secure frontend hosting
- **Pod Identity**: IAM integration without IRSA

### Well-Architected Alignment

- **Security**: Encryption at rest/transit, IAM auth, no static credentials, VPC endpoints
- **Reliability**: Multi-AZ, Auto Mode, Aurora clustering
- **Performance**: Mixed architecture, Spot instances, CloudFront CDN
- **Cost Optimization**: Spot capacity, lifecycle policies, VPC endpoints
- **Operational Excellence**: Infrastructure as Code, environment separation

## Quick Start

### Prerequisites

- AWS CLI configured
- Terraform >= 1.6
- kubectl

### Deploy Development Environment

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

### Configure kubectl

```bash
aws eks update-kubeconfig --region us-west-2 --name acmecorp-dev
```

### Post-Deployment Setup

1. **Create IAM Database User**:
   ```sql
   -- Connect to Aurora as postgres superuser
   CREATE USER iam_user WITH LOGIN;
   GRANT rds_iam TO iam_user;
   GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO iam_user;
   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO iam_user;
   ```

2. **Enable EKS Auto Mode**:
   - Auto Mode is enabled in the EKS cluster configuration via `compute_config`.

3. **Deploy Applications**:
   ```bash
   helm upgrade --install acmecorp ../../helm/acmecorp-platform -n acmecorp --create-namespace
   ```

## Module Structure

```
modules/
├── vpc/                 # Multi-AZ VPC with NAT gateways
├── eks-auto/           # EKS cluster with Auto Mode support
├── aurora-postgres/    # Aurora PostgreSQL with IAM auth
├── s3-frontend/        # S3 bucket for React frontend
├── cloudfront/         # CloudFront distribution with OAC
├── iam/               # IAM roles for Pod Identity
└── pod-identity/      # EKS Pod Identity associations
```

## Environment Configuration

### Development
- Single Aurora instance
- Smaller instance types
- 3-day backup retention
- CloudFront PriceClass_100

### Staging
- Production-like setup
- Isolated VPC (10.1.0.0/16)
- 3-day backup retention

### Production
- Multi-instance Aurora cluster
- Larger instance types
- 7-day backup retention
- Deletion protection enabled
- CloudFront PriceClass_All

## Security Features

### Network Security
- Private subnets for all workloads
- Security groups with least privilege
- VPC endpoints for AWS services
- No public database access

### Identity & Access
- Pod Identity (no IRSA)
- IAM database authentication
- Least privilege IAM policies
- No static credentials

### Encryption
- EKS etcd encryption (KMS)
- Aurora encryption at rest (KMS)
- S3 server-side encryption
- CloudFront HTTPS enforcement

## Capacity Management

### EKS Auto Mode Benefits
- Serverless node management
- Automatic scaling
- Mixed architecture support
- Spot instance optimization

### Node Pools (Post-Deployment)
- **System Pool**: On-Demand instances for reliability
- **Application Pool**: Spot-preferred for cost optimization

### Workload Scheduling
```yaml
# Application workloads
nodeSelector:
  workload-type: application
tolerations:
- key: workload-type
  value: application
  effect: NoSchedule
```

## Observability

### CloudWatch Integration
- EKS cluster logs
- Container Insights ready
- Service-specific log groups

### Monitoring Setup
```bash
# Enable Container Insights
aws eks update-cluster-config --name acmecorp-dev --logging '{"enable":["api","audit","authenticator","controllerManager","scheduler"]}'
```

## Cost Optimization

### Spot Instances
- Application workloads prefer Spot
- Automatic fallback to On-Demand
- Mixed instance types

### Storage Lifecycle
- S3 version cleanup (30 days)
- Aurora automated backups
- EBS volume optimization

## Troubleshooting

### Common Issues

1. **Pod Identity Not Working**
   ```bash
   # Check associations
   aws eks list-pod-identity-associations --cluster-name acmecorp-dev
   
   # Verify service account
   kubectl get sa -n acmecorp
   ```

2. **Aurora Connection Issues**
   ```bash
   # Test IAM auth token
   aws rds generate-db-auth-token --hostname <endpoint> --port 5432 --username iam_user
   ```

3. **EKS Auto Mode Not Enabled**
   Auto Mode is configured on the cluster itself. If it isn't enabled, verify
   the EKS cluster was created with `compute_config` set and the Auto Mode node
   role has the required policies attached.

### EKS Add-ons Enabled by Terraform

The following EKS managed add-ons are created:
- `eks-pod-identity-agent`
- `coredns`
- `kube-proxy`
- `vpc-cni`
- `aws-ebs-csi-driver`

### S3 Frontend Bucket Naming

The frontend bucket includes a short random suffix to avoid global S3 name collisions:
`<cluster>-frontend-<suffix>`.

## Code Quality & Linting

### TFLint Integration

The project includes comprehensive Terraform linting using [TFLint](https://github.com/terraform-linters/tflint) with AWS-specific rules.

#### Setup
```bash
# Install TFLint and AWS plugin
make install-tflint

# Run linting
make lint

# Run complete test suite (validate + format + lint)
make test ENV=dev
```

#### Linting Rules
- **Provider Constraints**: Ensures version constraints for all providers
- **Terraform Version**: Requires terraform version specification
- **Unused Variables**: Detects unused variable declarations
- **Module Structure**: Enforces standard module file structure
- **AWS Best Practices**: AWS-specific security and performance rules
- **Naming Conventions**: Enforces snake_case naming

#### Configuration
TFLint configuration is in `.tflint.hcl` with:
- AWS plugin for cloud-specific rules
- Standard Terraform best practices
- Module structure validation
- Documentation requirements

## Maintenance

### Terraform State
- Use S3 backend for production
- Enable state locking with DynamoDB
- Separate state per environment

### Updates
```bash
# Update Kubernetes version
terraform apply -var="kubernetes_version=1.32"

# Update Aurora engine
# (Requires maintenance window)
```

## Security Considerations

### Network Access
- EKS endpoint can be made private-only
- Aurora accessible only from VPC
- CloudFront enforces HTTPS

### Compliance
- Encryption at rest and in transit
- Audit logging enabled
- IAM authentication for databases
- No hardcoded credentials

## Performance Tuning

### Aurora Parameters
- `shared_preload_libraries = pg_stat_statements`
- `log_min_duration_statement = 1000`
- Performance Insights enabled

### EKS Optimization
- Mixed architecture support
- Spot instance diversity
- Auto Mode automatic optimization

## Disaster Recovery

### Backup Strategy
- Aurora automated backups
- S3 versioning enabled
- Infrastructure as Code

### Multi-Region Considerations
- Aurora Global Database (manual setup)
- CloudFront global distribution
- Cross-region VPC peering (if needed)
