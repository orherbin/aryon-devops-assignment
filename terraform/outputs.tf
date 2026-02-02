output "cluster_name" {
  description = "Name of the Minikube cluster"
  value       = minikube_cluster.cluster.cluster_name
}

output "namespace" {
  description = "Kubernetes namespace for applications"
  value       = var.namespace
}

output "postgresql_database" {
  description = "PostgreSQL database name"
  value       = var.postgresql_database
}

output "deploy_postgresql" {
  description = "Whether PostgreSQL was deployed"
  value       = var.deploy_postgresql
}

output "deploy_monitoring" {
  description = "Whether monitoring stack was deployed"
  value       = var.deploy_monitoring
}
