output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint for your EKS Kubernetes API"
  value       = module.eks.cluster_endpoint
}

output "argocd_loadbalancer_dns" {
  description = "The DNS name for the ArgoCD UI"
  value       = data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].hostname
}

