output "argocd_loadbalancer_dns" {
  description = "DNS name of the ArgoCD LoadBalancer"
  value       = data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].hostname
}