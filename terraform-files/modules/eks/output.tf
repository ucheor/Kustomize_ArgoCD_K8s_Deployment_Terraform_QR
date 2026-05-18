output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.cluster.name
}

output "cluster_endpoint" {
  description = "The endpoint for your EKS Kubernetes API"
  value       = aws_eks_cluster.cluster.endpoint
}