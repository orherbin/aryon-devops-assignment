resource "minikube_cluster" "cluster" {
  cluster_name       = var.cluster_name
  driver             = var.driver
  cpus               = var.cpus
  memory             = var.memory
  disk_size          = var.disk_size
  kubernetes_version = var.kubernetes_version

  addons = [
    "default-storageclass",
    "storage-provisioner",
    "metrics-server",
    "ingress"
  ]
}

resource "helm_release" "postgresql" {
  count = var.deploy_postgresql ? 1 : 0

  depends_on = [minikube_cluster.cluster]

  name             = "postgresql"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "postgresql"
  version          = "18.2.3"
  namespace        = var.namespace
  create_namespace = true

  values = [
    yamlencode({
      auth = {
        postgresPassword = var.postgresql_password
        database         = var.postgresql_database
      }
      primary = {
        persistence = {
          enabled = true
          size    = "1Gi"
        }
        initdb = {
          scripts = {
            "schema.sql" = file("${path.module}/../database/schema.sql")
          }
        }
        resources = {
          requests = {
            memory = "256Mi"
            cpu    = "250m"
          }
          limits = {
            memory = "512Mi"
            cpu    = "500m"
          }
        }
      }
    })
  ]

  wait    = true
  timeout = 300
}

resource "helm_release" "prometheus_stack" {
  count = var.deploy_monitoring ? 1 : 0

  depends_on = [minikube_cluster.cluster]

  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "81.4.2"
  namespace        = "monitoring"
  create_namespace = true

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          retention                               = "24h"
          resources = {
            requests = {
              memory = "400Mi"
              cpu    = "200m"
            }
          }
        }
      }
      grafana = {
        enabled                  = true
        adminPassword            = var.grafana_admin_password
        defaultDashboardsEnabled = false
        sidecar = {
          dashboards = {
            enabled         = true
            searchNamespace = "ALL"
          }
        }
      }
      alertmanager = {
        enabled = var.enable_alertmanager
      }
      defaultRules = {
        create = false
      }
    })
  ]

  wait    = true
  timeout = 600
}

resource "kubernetes_config_map_v1" "grafana_dashboard" {
  count = var.deploy_monitoring ? 1 : 0

  depends_on = [helm_release.prometheus_stack]

  metadata {
    name      = "application-dashboard"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "application-dashboard.json" = file("${path.module}/../monitoring/dashboards/application-dashboard.json")
  }
}
