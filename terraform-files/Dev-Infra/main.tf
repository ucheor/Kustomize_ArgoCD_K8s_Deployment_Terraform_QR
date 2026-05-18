module "vpc" {
  source           = "../modules/vpc"
  eks_cluster_name = var.eks_cluster_name
}


module "eks" {
  source           = "../modules/eks"
  eks_cluster_name = var.eks_cluster_name
  instance_types   = var.instance_types
  node_group_name  = var.node_group_name
  eks_version      = var.eks_version
  node_subnet_ids  = module.vpc.private_subnet_ids #private subnets ONLY for the nodes
  subnet_ids       = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
}

module "argocd" {
  source       = "../modules/argocd"
  service_type = var.service_type

  depends_on = [null_resource.wait_for_cluster]
}