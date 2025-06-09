variable "platform_access_key" {
  description = "vCluster platform API key"
  type        = string
  sensitive   = true
}

variable "platform_hostname" {
  description = "vCluster platform host URL"
  type        = string
}

variable "vcluster_namespace" {
  description = "vCluster ns"
  type        = string
}

variable "vcluster_name" {
  description = "vCluster name"
  type        = string
}

variable "vcluster_version" {
  description = "vCluster name"
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

resource "kubernetes_namespace" "vcluster_ns" {
  metadata {
    name = var.vcluster_namespace
  }
}

resource "kubernetes_secret" "vcluster_platform_api_key" {
  metadata {
    name      = "vcluster-platform-api-key"
    namespace = var.vcluster_namespace
    labels = {
      "vcluster.loft.sh/created-by-cli" = "true"
    }
  }
  data = {
    accessKey = var.platform_access_key
    host      = var.platform_hostname
    insecure  = "true"
    name      = var.vcluster_name
    project   = "default"
  }
  type = "Opaque"
  depends_on = [kubernetes_namespace.vcluster_ns]
}

resource "helm_release" "my_vcluster" {
  name       = var.vcluster_name
  namespace  = var.vcluster_namespace
  repository = "https://charts.loft.sh"
  chart      = "vcluster"
  version    = var.vcluster_version
  values = [
  templatefile("vcluster.yaml", {
    NAMESPACE = var.vcluster_namespace
  })
]
  depends_on = [kubernetes_secret.vcluster_platform_api_key]
}
