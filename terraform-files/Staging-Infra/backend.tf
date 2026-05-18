terraform {
  backend "s3" {
    bucket       = "argocd-trf-k8s-kustomize-demo" #update with your bucket name
    key          = "staging-infra/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}