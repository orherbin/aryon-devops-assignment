#!/bin/bash
#
# init.sh - Initialize the complete DevOps environment
#
# This script:
# 1. Creates a Minikube cluster using Terraform
# 2. Deploys PostgreSQL with schema initialization
# 3. Deploys Prometheus and Grafana monitoring stack
# 4. Builds Docker images for the applications
# 5. Deploys the applications using Helm
# 6. Sets up port-forward for local access
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
echo -e "${BLUE}  Aryon DevOps Assignment - Init${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        exit 1
    fi
}

# Function to get terraform output
tf_output() {
    terraform -chdir="$TERRAFORM_DIR" output -raw "$1" 2>/dev/null || echo ""
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
check_command docker
check_command minikube
check_command terraform
check_command helm
check_command kubectl

echo -e "${GREEN}All prerequisites installed!${NC}"
echo ""

# Step 1: Initialize Terraform and create cluster
echo -e "${BLUE}Step 1: Creating Minikube cluster with Terraform...${NC}"
cd "$TERRAFORM_DIR"

terraform init -upgrade

echo -e "${YELLOW}Applying Terraform configuration...${NC}"
terraform apply -auto-approve

echo -e "${GREEN}Cluster and infrastructure created!${NC}"
echo ""

# Extract values from Terraform outputs
CLUSTER_NAME=$(tf_output cluster_name)
NAMESPACE=$(tf_output namespace)
DEPLOY_POSTGRESQL=$(tf_output deploy_postgresql)
DEPLOY_MONITORING=$(tf_output deploy_monitoring)
DB_NAME=$(tf_output postgresql_database)

echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Cluster:    ${CLUSTER_NAME}"
echo -e "  Namespace:  ${NAMESPACE}"
echo -e "  PostgreSQL: ${DEPLOY_POSTGRESQL}"
echo -e "  Monitoring: ${DEPLOY_MONITORING}"
echo ""

# Step 2: Configure kubectl context and default namespace
echo -e "${BLUE}Step 2: Configuring kubectl context...${NC}"
minikube update-context -p "$CLUSTER_NAME"
kubectl config set-context --current --namespace="$NAMESPACE"
echo -e "${GREEN}kubectl configured for cluster '$CLUSTER_NAME' with default namespace '$NAMESPACE'${NC}"
echo ""

# Step 3: Wait for PostgreSQL to be ready
if [ "$DEPLOY_POSTGRESQL" = "true" ]; then
    echo -e "${BLUE}Step 3: Waiting for PostgreSQL...${NC}"
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n "$NAMESPACE" --timeout=300s
    echo -e "${GREEN}PostgreSQL is ready!${NC}"
else
    echo -e "${YELLOW}Step 3: PostgreSQL deployment skipped${NC}"
fi
echo ""

# Step 4: Wait for Prometheus stack
if [ "$DEPLOY_MONITORING" = "true" ]; then
    echo -e "${BLUE}Step 4: Waiting for monitoring stack...${NC}"
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s 2>/dev/null || echo "Grafana pods starting..."
    kubectl wait --for=condition=ready pod -l app=kube-prometheus-stack-operator -n monitoring --timeout=300s 2>/dev/null || echo "Prometheus operator starting..."
    echo -e "${GREEN}Monitoring stack is ready!${NC}"
else
    echo -e "${YELLOW}Step 4: Monitoring deployment skipped${NC}"
fi
echo ""

# Step 5: Build Docker images
echo -e "${BLUE}Step 5: Building Docker images...${NC}"
eval $(minikube docker-env -p "$CLUSTER_NAME")

echo "Building items-service..."
docker build -t items-service:latest "$PROJECT_DIR/items-service"

echo "Building audit-service..."
docker build -t audit-service:latest "$PROJECT_DIR/audit-service"

echo -e "${GREEN}Docker images built!${NC}"
echo ""

# Step 6: Deploy applications with Helm
echo -e "${BLUE}Step 6: Deploying applications with Helm...${NC}"

echo "Deploying audit-service (internal)..."
helm upgrade --install audit-service "$PROJECT_DIR/helm/microservice" \
    -f "$PROJECT_DIR/audit-service/values.yaml" \
    -n "$NAMESPACE" \
    --wait --timeout 5m

echo "Deploying items-service (public via Ingress)..."
helm upgrade --install items-service "$PROJECT_DIR/helm/microservice" \
    -f "$PROJECT_DIR/items-service/values.yaml" \
    -n "$NAMESPACE" \
    --wait --timeout 5m

echo -e "${GREEN}Applications deployed!${NC}"
echo ""

# Step 7: Wait for all pods to be ready
echo -e "${BLUE}Step 7: Verifying all pods are ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=microservice -n "$NAMESPACE" --timeout=120s
echo -e "${GREEN}All pods are ready!${NC}"
echo ""

# Print summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Access Services via Minikube Tunnel:${NC}"
echo -e "  Run in a separate terminal:"
echo -e "  ${YELLOW}minikube tunnel -p $CLUSTER_NAME${NC}"
echo ""
echo -e "  Then access:"
echo -e "  - Items Service: http://localhost/items"
if [ "$DEPLOY_MONITORING" = "true" ]; then
    echo -e "  - Grafana:       kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    echo -e "                   Then: http://localhost:3000"
    echo ""
    echo -e "${BLUE}Grafana Credentials:${NC}"
    echo -e "  Username: admin"
    echo -e "  Password: (set in terraform.tfvars or TF_VAR_grafana_admin_password)"
fi
echo ""

echo -e "${BLUE}Test the API (after starting minikube tunnel):${NC}"
echo -e "  # Create an item"
echo -e "  curl -X POST http://localhost/items \\"
echo -e "    -H 'Content-Type: application/json' \\"
echo -e "    -d '{\"name\": \"Test Item\", \"description\": \"Testing\"}'"
echo ""
echo -e "  # List items"
echo -e "  curl http://localhost/items"
echo ""
echo -e "${BLUE}View Metrics:${NC}"
echo -e "  curl http://localhost/metrics"
echo ""

if [ "$DEPLOY_POSTGRESQL" = "true" ]; then
    echo -e "${BLUE}Check Audit Logs:${NC}"
    echo -e "  kubectl exec -it \$(kubectl get pod -l app.kubernetes.io/name=postgresql -n ${NAMESPACE} -o name) -n ${NAMESPACE} \\"
    echo -e "    -- psql -U postgres -d ${DB_NAME} -c 'SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 5;'"
    echo ""
fi

echo -e "${YELLOW}To clean up, run: ./scripts/cleanup.sh${NC}"
