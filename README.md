# Automated EKS Infrastructure with Terraform, ArgoCD and Kustomize

My project is structured around the GitOps methodology, using Terraform for Infrastructure as Code (IaC), ArgoCD for continuous deployment on Amazon EKS and Kustomize for environment-specific configuration management.

## Features:
- **Terraform modules:** Using modules enable re-using the same code across multiple clusters and automating Kubernetes cluster deployment with ArgoCD integration

- **Kustomize:** This tool made it easy to manage the "last-mile" configuration of my Kubernetes manifests without needing to template my YAML files. By utilizing a base and overlay strategy, I was able to maintain a single source of truth while applying specific modifications for different environments.

- **App-of-Apps Implementation:** I use the App-of-Apps pattern to bootstrap the cluster, where one parent ArgoCD application manages child Kustomize applications for my networking, security, and MLOps tools.

- **GitOps with ArgoCD:** I integrated ArgoCD to ensure that my cluster's state always reflects my Git repository. ArgoCD acts as the controller that reconciles my desired Git state with the live cluster.   
