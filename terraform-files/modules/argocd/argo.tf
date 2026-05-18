resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "7.7.0" # choose appropriate version

  depends_on = [kubernetes_namespace.argocd]

  # Optional: Set custom values
  set {
    name  = "server.service.type"
    value = var.service_type
  }

  # Wait for the deployment to be ready
  wait    = true
  timeout = 300
}

data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server" # Standard name created by the argo-cd chart
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  depends_on = [helm_release.argocd]
}

