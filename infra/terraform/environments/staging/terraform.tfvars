environment        = "staging"
aws_region        = "us-west-2"
cluster_name      = "acmecorp"
kubernetes_version = "1.31"

vpc_cidr = "10.1.0.0/16"

# Use default AZs (first 3 available)
availability_zones = []

# Aurora configuration
db_name     = "acmecorp"
db_username = "iam_user"

# Frontend domain (empty for CloudFront default)
frontend_domain = ""

# Tagging
owner       = "platform-team"
cost_center = "engineering"