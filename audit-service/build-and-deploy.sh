#!/bin/bash
#
# build-and-deploy.sh - Build and deploy the Audit Service
#
# This script allows developers to quickly test their changes locally by:
# 1. Building the Docker image
# 2. Loading it into Minikube
# 3. Deploying/upgrading the Helm release
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

SERVICE_NAME="audit-service"
IMAGE_NAME="audit-service"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Build & Deploy - ${SERVICE_NAME}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to get terraform output
tf_output() {
    terraform -chdir="$TERRAFORM_DIR" output -raw "$1" 2>/dev/null || echo ""
}

# Get cluster configuration from Terraform
CLUSTER_NAME=$(tf_output cluster_name)
NAMESPACE=$(tf_output namespace)

if [ -z "$CLUSTER_NAME" ]; then
    echo -e "${RED}Error: Could not get cluster name from Terraform.${NC}"
    echo -e "${YELLOW}Make sure you have run ./scripts/init.sh first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Cluster:   ${CLUSTER_NAME}"
echo -e "  Namespace: ${NAMESPACE}"
echo -e "  Image:     ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

# Step 1: Configure Docker to use Minikube's daemon
echo -e "${BLUE}Step 1: Configuring Docker environment...${NC}"
eval $(minikube docker-env -p "$CLUSTER_NAME")
echo -e "${GREEN}Docker configured to use Minikube!${NC}"
echo ""

# Step 2: Build the Docker image
echo -e "${BLUE}Step 2: Building Docker image...${NC}"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" "$SCRIPT_DIR"
echo -e "${GREEN}Image built: ${IMAGE_NAME}:${IMAGE_TAG}${NC}"
echo ""

# Step 3: Deploy with Helm
echo -e "${BLUE}Step 3: Deploying with Helm...${NC}"
helm upgrade --install "$SERVICE_NAME" "$PROJECT_DIR/helm/microservice" \
    -f "$SCRIPT_DIR/values.yaml" \
    -n "$NAMESPACE" \
    --wait --timeout 2m
echo -e "${GREEN}Deployment complete!${NC}"
echo ""

# Step 4: Restart the deployment to pick up new image
echo -e "${BLUE}Step 4: Restarting deployment to use new image...${NC}"
kubectl rollout restart deployment "$SERVICE_NAME" -n "$NAMESPACE"
kubectl rollout status deployment "$SERVICE_NAME" -n "$NAMESPACE" --timeout=120s
echo -e "${GREEN}Rollout complete!${NC}"
echo ""

# Show pod status
echo -e "${BLUE}Pod Status:${NC}"
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$SERVICE_NAME"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ${SERVICE_NAME} deployed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Note: This is an internal service (ClusterIP only).${NC}"
echo -e "${YELLOW}It's accessed by items-service, not directly from outside.${NC}"
