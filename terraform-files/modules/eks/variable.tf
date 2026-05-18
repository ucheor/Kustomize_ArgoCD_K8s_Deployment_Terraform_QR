variable "eks_cluster_name" {}
  
variable "eks_version" {}
 
variable "node_group_name" {}

variable "instance_types" {}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the EKS cluster"
}

variable "node_subnet_ids" {
  type        = list(string)
  description = "Only Private subnets for the Worker Nodes"
}