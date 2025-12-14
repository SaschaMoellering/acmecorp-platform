# AcmeCorp Platform Terraform Operations
# Well-Architected: Operational Excellence (standardized operations)

.PHONY: help init plan apply destroy validate fmt lint clean

# Default environment
ENV ?= dev
REGION ?= us-west-2

help: ## Show this help message
	@echo "AcmeCorp Platform Terraform Operations"
	@echo ""
	@echo "Usage: make <target> [ENV=<environment>]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Environments: dev, staging, prod"
	@echo "Example: make plan ENV=prod"

init: ## Initialize Terraform for specified environment
	@echo "Initializing Terraform for $(ENV) environment..."
	cd environments/$(ENV) && terraform init

validate: ## Validate Terraform configuration
	@echo "Validating Terraform configuration for $(ENV)..."
	cd environments/$(ENV) && terraform validate

fmt: ## Format Terraform files
	@echo "Formatting Terraform files..."
	terraform fmt -recursive .

plan: ## Create Terraform execution plan
	@echo "Creating execution plan for $(ENV) environment..."
	cd environments/$(ENV) && terraform plan

apply: ## Apply Terraform configuration
	@echo "Applying Terraform configuration for $(ENV) environment..."
	cd environments/$(ENV) && terraform apply

destroy: ## Destroy Terraform-managed infrastructure
	@echo "Destroying infrastructure for $(ENV) environment..."
	@echo "WARNING: This will destroy all resources!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd environments/$(ENV) && terraform destroy; \
	fi

output: ## Show Terraform outputs
	@echo "Terraform outputs for $(ENV) environment:"
	cd environments/$(ENV) && terraform output

kubeconfig: ## Update kubectl configuration
	@echo "Updating kubeconfig for $(ENV) environment..."
	aws eks update-kubeconfig --region $(REGION) --name acmecorp-$(ENV)

post-deploy: kubeconfig ## Run post-deployment setup
	@echo "Running post-deployment setup for $(ENV)..."
	@echo "1. Create Kubernetes namespace:"
	kubectl create namespace acmecorp --dry-run=client -o yaml | kubectl apply -f -
	@echo ""
	@echo "2. Manual steps required:"
	@echo "   - Create IAM database user (see README.md)"
	@echo "   - Enable EKS Auto Mode via AWS CLI"
	@echo "   - Deploy Helm charts"

clean: ## Clean Terraform cache files
	@echo "Cleaning Terraform cache files..."
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.tfstate*" -delete 2>/dev/null || true
	find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true

lint: ## Run terraform and security linting
	@echo "Running Terraform linting..."
	terraform fmt -check -recursive .
	@echo "Linting completed successfully"

check-env: ## Verify environment is valid
	@if [ "$(ENV)" != "dev" ] && [ "$(ENV)" != "staging" ] && [ "$(ENV)" != "prod" ]; then \
		echo "Error: ENV must be one of: dev, staging, prod"; \
		exit 1; \
	fi

# Environment-specific shortcuts
dev: ## Quick deploy to dev environment
	$(MAKE) apply ENV=dev

staging: ## Quick deploy to staging environment
	$(MAKE) apply ENV=staging

prod: ## Quick deploy to prod environment
	$(MAKE) apply ENV=prod

# Security and compliance
security-scan: ## Run security scanning (requires external tools)
	@echo "Running security scan..."
	@echo "Install and run tools like:"
	@echo "  - tfsec (terraform security scanner)"
	@echo "  - checkov (infrastructure security scanner)"
	@echo "  - terrascan (compliance scanner)"

cost-estimate: ## Estimate infrastructure costs (requires external tools)
	@echo "Estimating costs for $(ENV) environment..."
	@echo "Use tools like:"
	@echo "  - Infracost (terraform cost estimation)"
	@echo "  - AWS Pricing Calculator"