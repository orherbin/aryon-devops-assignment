# =============================================================================
# Cluster Configuration
# =============================================================================

variable "cluster_name" {
  description = "Name of the Minikube cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for Minikube"
  type        = string
}

variable "driver" {
  description = "Minikube driver (docker, hyperkit, virtualbox, etc.)"
  type        = string
  default     = "docker"
}

variable "cpus" {
  description = "Number of CPUs for Minikube"
  type        = number
  default     = 4
}

variable "memory" {
  description = "Memory for Minikube in MB"
  type        = number
  default     = 8192
}

variable "disk_size" {
  description = "Disk size for Minikube"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for applications"
  type        = string
  default     = "default"
}

# =============================================================================
# Resource Deployment Flags
# =============================================================================

variable "deploy_postgresql" {
  description = "Whether to deploy PostgreSQL"
  type        = bool
  default     = true
}

variable "deploy_monitoring" {
  description = "Whether to deploy Prometheus and Grafana monitoring stack"
  type        = bool
  default     = true
}

variable "enable_alertmanager" {
  description = "Whether to enable Alertmanager in the monitoring stack"
  type        = bool
  default     = false
}

# =============================================================================
# PostgreSQL Configuration
# =============================================================================

variable "postgresql_password" {
  description = "PostgreSQL password for the postgres user"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "postgresql_database" {
  description = "PostgreSQL database name to create"
  type        = string
  default     = "itemsdb"
}

# =============================================================================
# Grafana Configuration
# =============================================================================

variable "grafana_admin_password" {
  description = "Grafana admin user password"
  type        = string
  default     = "admin"
  sensitive   = true
}
