# Aryon DevOps Take-Home Assignment

A containerized microservices deployment on Kubernetes with monitoring, demonstrating cloud-native best practices.

## Project Overview

This project deploys two Python Flask microservices to a local Minikube Kubernetes cluster:

- **Items Service** - A public-facing REST API that manages items (exposed via Ingress)
- **Audit Service** - An internal service that logs all operations (ClusterIP only)

Both services are backed by PostgreSQL and monitored with Prometheus/Grafana.

## Prerequisites

Before running this project, ensure you have the following tools installed:

| Tool      | Version | Installation                                                           |
| --------- | ------- | ---------------------------------------------------------------------- |
| Docker    | 20.10+  | [Install Docker](https://docs.docker.com/get-docker/)                  |
| Minikube  | 1.30+   | [Install Minikube](https://minikube.sigs.k8s.io/docs/start/)           |
| Terraform | 1.5+    | [Install Terraform](https://developer.hashicorp.com/terraform/install) |
| Helm      | 3.12+   | [Install Helm](https://helm.sh/docs/intro/install/)                    |
| kubectl   | 1.28+   | [Install kubectl](https://kubernetes.io/docs/tasks/tools/)             |

### Verify Installation

```bash
docker --version
minikube version
terraform --version
helm version
kubectl version --client
```

## Quick Start

### Step 1: Clone and Navigate

```bash
cd aryon-devops-assignment
```

### Step 2: Run the Init Script

This script will:

- Create a Minikube cluster using Terraform
- Deploy PostgreSQL with initialized schema (via Terraform Helm release)
- Deploy Prometheus and Grafana monitoring stack (via Terraform Helm release)
- Build Docker images for both services
- Deploy the applications using Helm

```bash
./scripts/init.sh
```

The script takes approximately 5-10 minutes to complete.

### Step 3: Start Minikube Tunnel

In a **separate terminal**, run:

```bash
minikube tunnel -p aryon-demo-cluster
```

This creates a route to the cluster's Ingress controller, making the Items Service accessible at `http://localhost`.

> **Note:** The tunnel requires sudo access and must remain running while you access the services.

## Testing the Application

### Create an Item

```bash
curl -X POST http://localhost/items \
  -H 'Content-Type: application/json' \
  -d '{"name": "Test Item", "description": "This is a test item"}'
```

### List All Items

```bash
curl http://localhost/items
```

### View Metrics

```bash
curl http://localhost/metrics
```

### Verify Audit Logs in Database

```bash
kubectl exec -it $(kubectl get pod -l app.kubernetes.io/name=postgresql -n aryon-demo -o name) -n aryon-demo \
  -- psql -U postgres -d itemsdb -c "SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 5;"
```

### Check Items in Database

```bash
kubectl exec -it $(kubectl get pod -l app.kubernetes.io/name=postgresql -n aryon-demo -o name) -n aryon-demo \
  -- psql -U postgres -d itemsdb -c "SELECT * FROM items ORDER BY created_at DESC LIMIT 5;"
```

## Accessing Grafana

Start port-forward for Grafana:

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Then open http://localhost:3000 in your browser.

**Credentials:**

- Username: `admin`
- Password: `admin` (or as configured in `terraform.tfvars`)

The **SLO Dashboard** is pre-configured with:

- Business metrics (items created, audit events)
- SLO overview (success rate, error rate, latency, throughput)
- Database performance metrics
- Resource utilization

## Developer Workflow ( Deployment Mechanism )

For iterating on a single service and test locally, make your changes to either the source code or the k8s values, and run:

```bash
# Rebuild and deploy items-service only
./items-service/build-and-deploy.sh

# Rebuild and deploy audit-service only
./audit-service/build-and-deploy.sh
```

## Cleanup

To tear down all resources:

```bash
./scripts/cleanup.sh
```

This will:

- Remove Helm releases
- Destroy Terraform resources
- Delete the Minikube cluster
- Clean up Docker images
- Remove Terraform state files


## Technologies Used

- **Infrastructure**: Terraform, Minikube
- **Containerization**: Docker (multi-stage builds)
- **Orchestration**: Kubernetes, Helm
- **Monitoring**: Prometheus, Grafana
- **Application**: Python Flask, Gunicorn
- **Database**: PostgreSQL
