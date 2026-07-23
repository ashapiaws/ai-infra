################################################################################
# Data Sources
################################################################################

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

################################################################################
# Provider Configuration
################################################################################

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

################################################################################
# Namespace
################################################################################

resource "kubernetes_namespace" "envoy" {
  metadata {
    name = var.envoy_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "envoy-gateway"
    }
  }
}

################################################################################
# Envoy Configuration (Static Bootstrap)
################################################################################

resource "kubernetes_config_map" "envoy_config" {
  metadata {
    name      = "envoy-config"
    namespace = kubernetes_namespace.envoy.metadata[0].name
  }

  data = {
    "envoy.yaml" = templatefile("${path.module}/manifests/envoy-bootstrap.yaml.tpl", {
      admin_port             = var.admin_port
      listener_port          = var.listener_port
      enable_admin_interface = var.enable_admin_interface
      upstream_clusters      = var.upstream_clusters
    })
  }
}

################################################################################
# Envoy Deployment
################################################################################

resource "kubernetes_deployment" "envoy" {
  metadata {
    name      = "envoy"
    namespace = kubernetes_namespace.envoy.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "envoy"
      "app.kubernetes.io/component" = "proxy"
    }
  }

  spec {
    replicas = var.envoy_replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "envoy"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "envoy"
          "app.kubernetes.io/component" = "proxy"
        }
        annotations = {
          "config-hash" = sha256(kubernetes_config_map.envoy_config.data["envoy.yaml"])
        }
      }

      spec {
        container {
          name  = "envoy"
          image = var.envoy_image

          args = [
            "-c", "/etc/envoy/envoy.yaml",
            "--service-cluster", "envoy-gateway",
            "--service-node", "envoy-gateway-node",
          ]

          port {
            name           = "http"
            container_port = var.listener_port
            protocol       = "TCP"
          }

          dynamic "port" {
            for_each = var.enable_admin_interface ? [1] : []
            content {
              name           = "admin"
              container_port = var.admin_port
              protocol       = "TCP"
            }
          }

          volume_mount {
            name       = "envoy-config"
            mount_path = "/etc/envoy"
            read_only  = true
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/ready"
              port = var.admin_port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = var.admin_port
            }
            initial_delay_seconds = 3
            period_seconds        = 5
          }
        }

        volume {
          name = "envoy-config"
          config_map {
            name = kubernetes_config_map.envoy_config.metadata[0].name
          }
        }
      }
    }
  }
}

################################################################################
# Envoy Service
################################################################################

resource "kubernetes_service" "envoy" {
  metadata {
    name      = "envoy-gateway"
    namespace = kubernetes_namespace.envoy.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "envoy"
    }
    annotations = var.envoy_service_type == "LoadBalancer" ? {
      "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internal"
      "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb"
    } : {}
  }

  spec {
    type     = var.envoy_service_type
    selector = {
      "app.kubernetes.io/name" = "envoy"
    }

    port {
      name        = "http"
      port        = 80
      target_port = var.listener_port
      protocol    = "TCP"
    }

    dynamic "port" {
      for_each = var.enable_admin_interface ? [1] : []
      content {
        name        = "admin"
        port        = var.admin_port
        target_port = var.admin_port
        protocol    = "TCP"
      }
    }
  }
}
