terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.30.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.3"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Wait for EKS cluster to be fully available using module outputs
resource "null_resource" "wait_for_cluster" {
  depends_on = [module.eks] # Wait for the whole module to finish

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for EKS cluster to be ready..."
      aws eks wait cluster-active --name ${var.eks_cluster_name} --region us-east-1
      aws eks update-kubeconfig --name ${var.eks_cluster_name} --region us-east-1 --alias ${var.eks_cluster_name}
      echo "Cluster is ready!"
    EOT
  }
}

# Data source using the variable directly since we know the name
data "aws_eks_cluster" "cluster" {
  name       = var.eks_cluster_name
  depends_on = [null_resource.wait_for_cluster]
}

data "aws_eks_cluster_auth" "cluster" {
  name       = var.eks_cluster_name
  depends_on = [null_resource.wait_for_cluster]
}

# Kubernetes provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.name]
    command     = "aws"
  }
}

data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = "argocd"
  }

  depends_on = [module.argocd]
}

# Helm provider
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.name]
      command     = "aws"
    }
  }
}