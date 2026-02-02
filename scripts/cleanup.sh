#!/bin/bash
#
# cleanup.sh - Clean up all resources created by init.sh
#
# This script:
# 1. Deletes Helm releases
# 2. Destroys Terraform resources (Minikube cluster)
# 3. Removes Docker images and Terraform state
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_DIR/terraform"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Aryon DevOps Assignment - Cleanup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to get terraform output
tf_output() {
    terraform -chdir="$TERRAFORM_DIR" output -raw "$1" 2>/dev/null || echo ""
}

# Try to get values from terraform outputs
CLUSTER_NAME=""
NAMESPACE="default"

if [ -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
    CLUSTER_NAME=$(tf_output cluster_name)
    NAMESPACE=$(tf_output namespace)
    NAMESPACE=${NAMESPACE:-default}
fi

echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Cluster:   ${CLUSTER_NAME:-'(not found)'}"
echo -e "  Namespace: ${NAMESPACE}"
echo ""

# Step 1: Delete Helm releases (if cluster exists)
echo -e "${BLUE}Step 1: Removing Helm releases...${NC}"
if [ -n "$CLUSTER_NAME" ] && minikube status -p "$CLUSTER_NAME" &>/dev/null; then
    # Configure kubectl to use the cluster
    minikube update-context -p "$CLUSTER_NAME" 2>/dev/null || true
    
    # Delete application releases
    helm uninstall items-service -n "$NAMESPACE" 2>/dev/null || echo "items-service not found, skipping..."
    helm uninstall audit-service -n "$NAMESPACE" 2>/dev/null || echo "audit-service not found, skipping..."
    
    echo -e "${GREEN}Helm releases removed!${NC}"
else
    echo -e "${YELLOW}Cluster not running, skipping Helm cleanup...${NC}"
fi
echo ""

# Step 2: Destroy Terraform resources
echo -e "${BLUE}Step 2: Destroying Terraform resources...${NC}"

if [ -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
    # Use -var-file to avoid prompts, and -refresh=false to skip API calls to deleted resources
    terraform -chdir="$TERRAFORM_DIR" destroy -auto-approve \
        -var-file="terraform.tfvars" \
        -refresh=false \
        2>/dev/null || {
            echo -e "${YELLOW}Terraform destroy had errors (resources may already be deleted)${NC}"
        }
    echo -e "${GREEN}Terraform resources destroyed!${NC}"
else
    echo -e "${YELLOW}No Terraform state found, skipping...${NC}"
fi
echo ""

# Step 3: Clean up Minikube (if still exists)
echo -e "${BLUE}Step 3: Cleaning up Minikube cluster...${NC}"
if [ -n "$CLUSTER_NAME" ] && minikube status -p "$CLUSTER_NAME" &>/dev/null; then
    minikube delete -p "$CLUSTER_NAME"
    echo -e "${GREEN}Minikube cluster deleted!${NC}"
else
    echo -e "${YELLOW}Cluster already deleted, skipping...${NC}"
fi
echo ""

# Step 4: Clean up Docker images
echo -e "${BLUE}Step 4: Cleaning up Docker images...${NC}"
docker rmi items-service:latest 2>/dev/null || echo "items-service image not found"
docker rmi audit-service:latest 2>/dev/null || echo "audit-service image not found"
echo -e "${GREEN}Docker images cleaned!${NC}"
echo ""

# Step 5: Clean up Terraform state
echo -e "${BLUE}Step 5: Cleaning up Terraform files...${NC}"
rm -rf "$TERRAFORM_DIR/.terraform" "$TERRAFORM_DIR/terraform.tfstate" "$TERRAFORM_DIR/terraform.tfstate.backup" "$TERRAFORM_DIR/.terraform.lock.hcl" 2>/dev/null || true
echo -e "${GREEN}Terraform files cleaned!${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}All resources have been removed.${NC}"
echo -e "${BLUE}To redeploy, run: ./scripts/init.sh${NC}"
