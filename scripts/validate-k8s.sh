#!/bin/bash
set -e

echo "🔍 Validating Kubernetes Artifacts"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
        exit 1
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 1. Validate YAML syntax of base K8s manifests
echo "1. Validating base Kubernetes manifests..."
for file in infra/k8s/base/*.yaml; do
    if [ -f "$file" ]; then
        if python3 -c "import yaml; list(yaml.safe_load_all(open('$file')))" 2>/dev/null; then
            print_status 0 "$(basename $file) syntax"
        else
            print_status 1 "$(basename $file) syntax"
        fi
    fi
done

# 2. Validate Helm templates
echo -e "\n2. Validating Helm templates..."
helm template acmecorp helm/acmecorp-platform -f helm/test-values.yaml > /tmp/helm-rendered.yaml 2>/dev/null
print_status $? "Helm template rendering"

# Count rendered resources
resource_count=$(grep -c "^kind:" /tmp/helm-rendered.yaml 2>/dev/null || echo "0")
echo "   📊 Rendered $resource_count Kubernetes resources"

# 3. Check for common issues
echo -e "\n3. Checking for common issues..."

# Check for missing resource limits
missing_limits=$(helm template acmecorp helm/acmecorp-platform -f helm/test-values.yaml | grep -A 20 "kind: Deployment" | grep -c "resources:" || echo "0")
total_deployments=$(helm template acmecorp helm/acmecorp-platform -f helm/test-values.yaml | grep -c "kind: Deployment" || echo "0")
if [ "$missing_limits" -lt "$total_deployments" ]; then
    print_warning "Some deployments may be missing resource limits"
else
    print_status 0 "Resource limits configured"
fi

# Check for security contexts
security_contexts=$(helm template acmecorp helm/acmecorp-platform -f helm/test-values.yaml | grep -c "securityContext:" || echo "0")
if [ "$security_contexts" -gt 0 ]; then
    print_status 0 "Security contexts found"
else
    print_warning "No security contexts found - consider adding for production"
fi

# 4. Validate network policies
echo -e "\n4. Validating network policies..."
if [ -f "infra/k8s/base/network-policies.yaml" ]; then
    python3 -c "import yaml; yaml.safe_load(open('infra/k8s/base/network-policies.yaml'))" 2>/dev/null
    print_status $? "Network policies syntax"
else
    print_warning "No network policies found"
fi

# 5. Check Helm chart structure
echo -e "\n5. Validating Helm chart structure..."
helm lint helm/acmecorp-platform > /dev/null 2>&1
print_status $? "Helm chart linting"

# 6. Validate resource quotas
echo -e "\n6. Validating resource quotas..."
if [ -f "infra/k8s/base/resource-quota.yaml" ]; then
    python3 -c "import yaml; yaml.safe_load(open('infra/k8s/base/resource-quota.yaml'))" 2>/dev/null
    print_status $? "Resource quota syntax"
else
    print_warning "No resource quotas found"
fi

# Clean up
rm -f /tmp/helm-rendered.yaml

echo -e "\n🎉 Kubernetes artifacts validation completed!"
echo "   📁 Base manifests: $(ls infra/k8s/base/*.yaml 2>/dev/null | wc -l) files"
echo "   📦 Helm templates: $resource_count resources"
echo -e "\n💡 Next steps:"
echo "   • Test with: kubectl apply --dry-run=client -f <manifest>"
echo "   • Deploy with: helm install acmecorp helm/acmecorp-platform"