variable "platform_access_key" {
  description = "vCluster platform API key"
  type        = string
  sensitive   = true
}

variable "platform_hostname" {
  description = "vCluster platform host URL"
  type        = string
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "random_id" "vcluster" {
  byte_length = 4
}

locals {
  vcluster_name = "terraform-vcluster-${random_id.vcluster.hex}"
}

resource "kubernetes_namespace" "vcluster_ns" {
  metadata {
    name = local.vcluster_name
  }
}

resource "kubernetes_secret" "vcluster_platform_api_key" {
  metadata {
    name      = "vcluster-platform-api-key"
    namespace = kubernetes_namespace.vcluster_ns.metadata[0].name
    labels = {
      "vcluster.loft.sh/created-by-cli" = "true"
    }
  }
  data = {
    accessKey = var.platform_access_key
    host      = var.platform_hostname
    insecure  = "true"
    name      = local.vcluster_name
    project   = "default"
  }
  type = "Opaque"
}

resource "helm_release" "my_vcluster" {
  name       = local.vcluster_name
  namespace  = kubernetes_namespace.vcluster_ns.metadata[0].name
  repository = "https://charts.loft.sh"
  chart      = "vcluster"
  version    = "0.25.0-beta.2"
  values = [
    file("vcluster.yaml")
  ]
  depends_on = [kubernetes_secret.vcluster_platform_api_key]
}

output "vcluster_name" {
  value = local.vcluster_name
}
