# CD Strategy and Tool Choices

## Continuous Delivery Strategy

### Recommended Approach: GitOps with ArgoCD

For this microservices architecture, I recommend implementing GitOps using ArgoCD for continuous delivery.

#### GitOps Principles

1. **Declarative Configuration**: All Kubernetes manifests are stored in Git
2. **Version Controlled**: Git serves as the single source of truth
3. **Automated Synchronization**: ArgoCD continuously reconciles desired state with actual state
4. **Pull-Based Deployment**: The cluster pulls changes rather than CI pushing

#### Proposed Pipeline

1. Developer pushes code to GitHub
2. GitHub Actions runs CI pipeline (lint, test, build image)
3. Image is pushed to container registry with semantic version tag
4. CI updates Helm values with new image tag in a GitOps repo
5. ArgoCD detects change and syncs to Kubernetes cluster

## Tools Chosen and Rationale

### Infrastructure: Terraform

**Why Terraform:**

- Industry standard for Infrastructure as Code
- Declarative syntax with state management
- Provider ecosystem (supports Kubernetes, AWS, GCP, Azure)
- Reproducible infrastructure
- Easy to extend for cloud deployment

### Container Orchestration: Kubernetes

**Why Kubernetes:**

- Industry standard for container orchestration
- Rich ecosystem (Helm, operators, service mesh)
- Portable across cloud providers
- Built-in service discovery and load balancing

### Package Management: Helm

**Why Helm:**

- Templated Kubernetes manifests
- Version-controlled releases with rollback
- Values-based configuration per environment
- Large chart repository ecosystem

**Design Decision - Generic Chart:**
Created a single reusable `microservice` chart that all services use with different values files, versioned controlled. This:

- Reduces code duplication
- Ensures consistency across services
- Makes adding new services trivial

### Monitoring: Prometheus + 3rd Party Observability Tool ( e.g New Relic )

**Why Prometheus:**

- De facto standard for Kubernetes monitoring
- Pull-based metrics collection
- Powerful query language (PromQL)
- Native Kubernetes service discovery
- AlertManager integration

## Summary

In conclusion, ideal flow in my mind will look something like this:

1. Local development using tools such as Tilt for fast "CICD".
2. Pushes the code to master will trigger GH action that will build the image, push to ECR and deploys to staging using ArgoCD.
3. Deployment to production are done manually for maximum control, and it's performed the same way with Argo, only by manual dispatch.

## Stuff I would of add with more time:

- Stress test script to test the system under load.
- Troubleshooting guide of common issues
- Change to local chart instead of bitnami since its about to be deprecated
- Implement proper image versioning mechanism
