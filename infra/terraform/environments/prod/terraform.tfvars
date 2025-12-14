environment        = "prod"
aws_region        = "us-west-2"
cluster_name      = "acmecorp"
kubernetes_version = "1.31"

vpc_cidr = "10.2.0.0/16"

# Specify AZs for production
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

# Aurora configuration
db_name     = "acmecorp"
db_username = "iam_user"

# Frontend domain (configure with your domain)
frontend_domain = ""  # Set to your domain, e.g., "app.acmecorp.com"

# Tagging
owner       = "platform-team"
cost_center = "engineering"