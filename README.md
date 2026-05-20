
# Simplifying Automation with Template-Based Processes and Modules   

## Docker  ·  Terraform Modules  ·  Amazon EKS  ·  ArgoCD GitOps  ·  Kustomize   

### Overview   
Managing infrastructure and application deployments across multiple environments is one of the most common sources of toil in modern software teams. Without disciplined automation, teams are forced to repeat the same manual steps for every environment, every cluster, and every application variant. Small differences between environments accumulate into configuration drift, and a single forgotten flag during a manual deploy can cause an outage in production.   

This project demonstrates a complete, end-to-end solution to that problem. By combining four complementary tools — Docker for reproducible image builds, Terraform modules for reusable infrastructure, ArgoCD for GitOps-driven deployments, and Kustomize for environment-specific configuration — the entire workflow from a single source of truth in Git to running applications on Kubernetes becomes automated, auditable, and trivially repeatable.   

### The Pain Points This Project Solves   

•	**Manual, error-prone environment setup:** Spinning up a new Kubernetes cluster with all its dependencies (VPC, node groups, ArgoCD, IAM roles) by hand is slow and inconsistent. Terraform modules wrap this complexity so the same tested code provisions every cluster.   

•	**Duplicated configuration across environments:** Copying Kubernetes manifests between dev and staging and editing values by hand is fragile. Kustomize overlays let a single base define the app structure while each environment only declares what is different (replica count, namespace, image tag).   

•	**No single source of truth:** When deployments happen via ad-hoc kubectl commands or CI pipelines that push directly to clusters, it becomes impossible to know the true desired state of the system. ArgoCD makes Git the single source of truth and continuously reconciles the cluster to match it.   

•	**Rebuilding similar images by hand:** The four themed application images (blue, green, orange, charcoal) share an identical structure but differ only in colour values. A parameterised shell script using Docker build arguments eliminates the need to maintain four separate Dockerfiles.   

•	**Slow feedback on infrastructure changes:** Without automation, verifying that a Terraform change will work requires careful manual review. The modular structure makes the plan output readable and the apply step predictable.   

**Key insight:**   
Every part of this project is a template. Terraform modules are templates for infrastructure. The build script is a template for images. Kustomize bases are templates for Kubernetes manifests. ArgoCD Application manifests are templates for GitOps deployments. Templates compose, and composed templates scale.   


## Step 1 — Build and Publish Docker Images   
The application is a simple nginx-based static website. Rather than creating four separate Dockerfiles that are nearly identical, a single parameterised Dockerfile and a build shell script handle all four colour variants in one pass.   

### Project File Structure:  
The apps/ directory contains three files:   
•	**Dockerfile:** defines the nginx container with build arguments for primary colour, secondary colour, and site name   
•	**index.html:** the HTML template with colour placeholder tokens   
•	**build.sh:** a shell script that iterates over a theme map and invokes docker build for each variant   

---
![application file](images/01_creating_application%20files.png)

---    

The build script declares an associative array mapping theme names to their colour values and site name. For each theme it runs docker build passing the values as --build-arg flags, producing a tagged image like argocd-trf-k8s-demo-blue:latest.   

**Running the Build:**     
With Docker Desktop running and its engine confirmed active:  

---
![Figure 2 — Docker Desktop with engine running](images/02_docker_desktop_running.png)

---

Navigate to the apps/ directory and execute the script: **./build.sh.** The script builds all four images sequentially. Docker's layer cache makes subsequent builds fast because the nginx:alpine base layer is shared across all variants.   

---
![Figure 3 — Terminal output showing all four themed images being built](images/02_docker_images_built.png)

---

After the script completes, docker images confirms all four are present locally:  
```
docker images
``` 

---
![Figure 4 — docker images output listing all four argocd-trf-k8s-demo variants](images/04_docker_images.png)

---
![Figure 5 — Docker Desktop Images tab confirming the four local images](images/05_docker_desktop_images_built.png)

---

**Tag and Push to Repository**   
To make the images available to Kubernetes, each image is tagged with the Docker registry username and version, then pushed to the registry. In this instance, we are working with Docker Hub as our *public* registry:   

```
docker tag argocd-trf-k8s-demo-blue:latest <registry_username>/argocd-trf-k8s-demo-blue:v1
docker push <registry_username>/argocd-trf-k8s-demo-blue:v1
```

The same pattern repeats for charcoal, green, and orange application images.   

---
![Figure 6 — Tagging and pushing all four images to Docker Hub](images/06_tag_and_push_to_repo.png)

---
![Figure 7 — Docker Hub showing all four public repositories pushed successfully](images/07_pushed_to_repo.png)

---

**Outcome:**  
Four themed Docker images are now available on Docker Hub and ready to be referenced by Kubernetes deployments. The entire build was driven by a single script — no Dockerfile duplication required.   

## Step 2 — Structure Kubernetes Manifests with Kustomize   
Before provisioning any infrastructure, the GitOps manifests need to be ready in the repository. Kustomize provides a base-plus-overlays pattern: a shared base directory holds the canonical Deployment, Service, and Kustomization files for each application, and environment-specific overlay directories inherit from those bases and declare only what changes per environment.   

**Directory Layout:**   
The kustomize-ArgoCD/ directory follows this structure:    
•	base/{blue,charcoal,green,orange}/ — canonical deployment.yaml, service.yaml, kustomization.yaml  
•	Dev-Cluster/overlays/{blue,charcoal,green,orange}/ — overlay kustomization.yaml for the dev environment  
•	Staging-Cluster/overlays/{blue,charcoal,green,orange}/ — overlay kustomization.yaml for the staging environment  
•	Dev-Cluster/argocd-apps/ — one ArgoCD Application manifest per colour  
•	Staging-Cluster/argocd-apps/ — equivalent ArgoCD Application manifests for staging environment   

--- 
![Figure 8 — Full kustomize-ArgoCD directory tree showing base, overlays, and argocd-apps for both clusters](images/09_argo_manifests_files_and_directories.png)

---

**How Overlays Work:**  
Each overlay kustomization.yaml points to the shared base with a relative path (../../base/blue), then only specifies what differs: the namespace, a name prefix, the image tag, and the replica count.   
For example, the dev overlay for the blue app sets replicas: 1 and namespace dev-blue, while the staging overlay sets replicas: 3 and namespace staging-blue. Everything else like the container spec, port definitions, and labels is inherited unchanged from the base.   

---
![Figure 9 — Side-by-side kustomization.yaml: staging overlay sets replicas: 3 while dev sets replicas: 1](images/37_using_overlay_to_adjust_replicas.png)

---

**ArgoCD Application Manifests**  
Each ArgoCD Application manifest in argocd-apps/ tells ArgoCD where to find the Kustomize overlay for a given colour and which cluster namespace to deploy into. Remember to update the repoURL field to point to your fork of the repository.   

---
![Figure 10 — orange-app.yaml ArgoCD Application manifest showing repoURL, overlay path, and sync policy](images/08_update_repository_path.png)

---

**Outcome:**   
A single base definition serves both clusters. Any change to the base (e.g. updating the container port) automatically applies everywhere. Environment-specific differences are confined to small, easy-to-review overlay files.   

## Step 3 — Provision the Dev Cluster with Terraform Modules  
We are using terraform to provision both EKS clusters and install ArgoCD into each cluster using the Helm provider. The infrastructure code has been structured as reusable modules — the VPC, EKS cluster, and ArgoCD installation logic each live in a dedicated module under terraform-files/modules/. The Dev-Infra/ and Staging-Infra/ directories simply call those shared modules with their own variable values. This way, we can easy customize each cluster using the associated variable files.   

**Module Structure:**    

---
![Figure 11 — Terraform directory tree: Dev-Infra, Staging-Infra, and shared modules (vpc, eks, argocd)](images/10_terraform_files_k8s_cluster.png)

---

The three shared modules are:   
•	modules/vpc — creates VPC, subnets, NAT gateway, and route tables   
•	modules/eks — creates the EKS cluster, node group, and cluster IAM roles   
•	modules/argocd — installs ArgoCD into the cluster via Helm, and exposes it through a LoadBalancer service    


**Environment Variables:**   
Each environment's variable.tf sets environment-specific values. In this demo, the Dev environment uses cluster name dev-cluster and node group name dev-cluster-nodes, while Staging uses staging-cluster and staging-cluster-nodes. Both use t3.medium instances and EKS version 1.31.   

---
![Figure 12 — variable.tf side-by-side: Dev-Infra (left) and Staging-Infra (right) with environment-specific cluster names](images/11_terraform_variable_files.png)

---

**S3 Backend for State:**   
Our Terraform state is stored remotely in an S3 bucket. For our demonstration, each bucket holds both environment state files, differentiated by key: dev-infra/terraform.tfstate and staging-infra/terraform.tfstate. remember to create your bucket for the backend and update the backend.tf files before running terraform init.   

---
![Figure 13 — AWS S3 bucket argocd-trf-k8s-kustomize-demo created successfully](images/12_backend_s3_bucket.png)

---
![Figure 14 — backend.tf for both environments pointing to the same S3 bucket with separate state keys](images/13_update_backend_s3_bucket_name.png)

---

**Initialise, Plan, and Apply:**   
From the Dev-Infra/ directory:
```
terraform init      # to configure the backend and install required providers
```
---
![Figure 15 — terraform init: S3 backend configured, all providers installed successfully](images/14_terraform_init.png)

---

![Figure 16 — terraform plan: 33 resources to add, outputs include argocd_loadbalancer_dns and cluster_name](images/15_terraform_plan_output_human_readable.png)

---

```
terraform apply      # to provision declared resources
```

---
![Figure 17 — terraform apply: confirmed with 'yes', VPC, EIP, and IAM resources begin creating](images/16_terraform_apply.png)

---

![Figure 18 — Apply outputs: argocd_loadbalancer_dns, cluster_endpoint, cluster_name = 'dev-cluster'](images/17_terraform_apply_successful.png)

---

**Verifying ArgoCD:**  
Once apply completes, update the local kubeconfig and check the ArgoCD namespace:   
```
aws eks update-kubeconfig --region us-east-1 --name dev-cluster
kubectl get all -n argocd
```

---
![Figure 19 — kubectl get all -n argocd: all pods Running, argocd-server exposed via LoadBalancer ALB](images/19_argocd_namespace_up_and_running.png)

---
![Figure 20 — ArgoCD login page accessible via the ALB DNS](images/18_argocd_provisioned_with_cluster_ALB.png)

---

The initial admin password is stored as a Kubernetes secret and retrieved with:
```
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

---
![Figure 21 — Retrieving the ArgoCD initial admin password via kubectl](images/20_get_argocd_initial_password.png)

---

**Outcome:**   
A fully operational EKS cluster with ArgoCD pre-installed and exposed via an ALB is provisioned with a single terraform apply command. The same module code will be reused to provision the staging cluster in Step 5.   

## Step 4 — Configure ArgoCD GitOps on the Dev Cluster  
With ArgoCD running, it needs to be told where the manifests live (the GitHub repository) and what to deploy (the Application resources). Rather than creating four separate ArgoCD Application resources manually, the App of Apps pattern is used: a single parent application points to the argocd-apps/ directory, and ArgoCD automatically discovers and deploys all four child applications from the YAML files it finds there.   

**Login to ArgoCD and Connect the GitHub Repository:**   

---
![Figure 22 — ArgoCD UI after login: empty Applications page ready for configuration](images/21_argocd_login_successful.png)

---

Navigate to Settings → Repositories → Connect Repo. Choose connection via HTTPS and paste the GitHub repository URL. No credentials are needed for the public repository used in this demo.  

---
![Figure 23 — ArgoCD Settings: Connect Repo form with GitHub URL entered](images/22_connect_repository.png)

---

![Figure 24 — Repository connected successfully with green Successful status](images/23_repository_connected.png)

---

**Create the Dev App of Apps:**   
Click + New App and fill in the form:   
•	Application Name: dev-app-of-apps   
•	Project: default, Sync Policy: Automatic   
•	Repository URL: the connected GitHub repo   
•	Path: kustomize-ArgoCD/Dev-Cluster/argocd-apps   
•	Destination Cluster URL: https://kubernetes.default.svc   
•	Namespace: argocd



---
![Figure 25 — New App form: application name, project, and automatic sync policy](images/24_set_up_argocd_apps.png)

---

![Figure 26 — Source path and destination cluster/namespace configuration](images/25_source_and_destination.png)

---

When the app-of-apps is created, ArgoCD reads the four YAML files in argocd-apps/ and automatically creates and syncs the blue, charcoal, green, and orange child applications.   

---
![Figure 27 — ArgoCD Applications tile view: all five apps Healthy and Synced](images/26_dev-cluster_applications_deploying.png)

---

**Verifying the Deployments:**

```
kubectl get namespace
kubectl get all -n dev-blue
kubectl get all -n dev-charcoal
kubectl get all -n dev-green
kubectl get all -n dev-orange
```
---
![Figure 28 — kubectl get namespace: dev-blue, dev-charcoal, dev-green, dev-orange all Active](images/27_namespaces_created_by_argocd.png)

---

All namespaces, application and serices are up and running.

---
![Figure 29 — kubectl get service per namespace: each app has a LoadBalancer with its own ALB DNS](images/28_apps_deployed.png)

---

In this demonstration, each application has its own LoadBalancer service, so they can be accessed independently. Opening each ALB URL in a browser and accessing the appropriate port reveals the themed application:   

---
![Figure 30 — ArgoCD-TrF-K8s-Demo-Blue running in the dev cluster](images/29_blue_app_dev.png)

---
![Figure 31 — ArgoCD-TrF-K8s-Demo-Green running in the dev cluster](images/30_green_app_dev.png)

---
![Figure 32 — ArgoCD-TrF-K8s-Demo-Charcoal running in the dev cluster](images/31_charcoal_app_dev.png)

---
![Figure 33 — ArgoCD-TrF-K8s-Demo-Orange running in the dev cluster](images/32_orange_app_dev.png)

---

### The App of Apps Resource Graph   

The ArgoCD UI shows the resource graph for the parent application, making the relationship between the app-of-apps and its four children immediately visible:   

---
![Figure 34 — dev-app-of-apps resource graph: parent app managing blue, charcoal, green, and orange child apps](images/33_app_of_apps_running.png)

---

![Figure 35 — ArgoCD blue app resource tree: service, deployment, replicaset, and running pod](images/34_dev_pods_running.png)

---

**Outcome:**    
Four applications are live on the dev cluster, each in its own namespace, each with its own ALB, and all managed automatically by ArgoCD from Git. Any commit that changes a manifest in the repository is automatically reconciled to the cluster within minutes — no kubectl apply required.

## Step 5 — Deploy the Staging Cluster and Validate Kustomize Overlays  

With dev working, the staging cluster is provisioned using exactly the same Terraform module code. Only the variable values change. This is the payoff for the modular structure: there is no new infrastructure code to write.   

**Provision Staging with Terraform:**   
Switch to the Staging-Infra/ directory and run:

```
terraform init && terraform apply 
```

---
![Figure 36 — terraform init and apply running in Staging-Infra/](images/35_deploy_staging_cluster.png)

---

![Figure 37 — Staging apply outputs: cluster_name = 'staging-cluster', ArgoCD ALB DNS, kubeconfig updated](images/36_staging_cluster_deployed.png)

---

**Connect ArgoCD to the Staging Cluster:**   
Update kubeconfig to the staging cluster context, retrieve the initial password from the ArgoCD secret, log into the new ArgoCD instance, connect the same GitHub repository, and create a staging-app-of-apps Application pointing to kustomize-ArgoCD/Staging-Cluster/argocd-apps.   

To switch context to your new cluster
```
aws eks update-kubeconfig --region us-east-1 --name <cluster_name>
```

---
![Figure 38 — staging-app-of-apps resource graph: all four staging apps Healthy and Synced](images/38_staging_apps_deployed.png)

---

**Staging Namespaces Created:**

Let's go ahead and verify the Staging environment deployments

```
kubectl get namespace
kubectl get all -n dev-blue
kubectl get all -n dev-charcoal
kubectl get all -n dev-green
kubectl get all -n dev-orange
```

---
![Figure 39 — kubectl get namespace on staging cluster: staging-blue, staging-charcoal, staging-green, staging-orange Active](images/40_staging_namespaces_created.png)

---

**Kustomize Overlay in Action: Replicas**    

The most visible difference between dev and staging is the replica count. The staging overlay sets replicas: 3 for each application, while dev sets replicas: 1. This is declared in a single line in each overlay's kustomization.yaml — no Deployment YAML is copied or modified.   
ArgoCD shows three pods running per staging application, confirming that Kustomize applied the overlay correctly:   

---
![Figure 40 — ArgoCD staging blue app: three pods running (staging-blue-5bbc9c7695-*) from the replicas: 3 overlay](images/39_staging_3_replicas.png)

---

All Staging Applications are Running   

![Figure 41 — kubectl get pods on all staging namespaces: 3 pods per app, all Running](images/41_staging_applications_deployed.png)

---
![Figure 42 — Green staging application live in browser via its LoadBalancer ALB](images/42_staging-dev_deployed.png)

---
**Outcome:** 
The staging cluster runs the same four applications as dev but with three replicas each, proving that the Kustomize overlay mechanism correctly differentiates environments. No manifest was duplicated — only the diff was declared.

## Step 6 — Teardown

Tearing down the environment cleanly requires deleting ArgoCD-managed resources before running terraform destroy, to prevent Terraform from getting stuck waiting on LoadBalancer finalizers that ArgoCD would otherwise recreate.   

**Remove ArgoCD Applications:**   
In the ArgoCD UI, delete the app-of-apps using the foreground propagation policy. This cascades the deletion to all child applications and their managed Kubernetes resources.   

---
![Figure 43 — ArgoCD delete dialog for staging-app-of-apps with foreground propagation policy selected](images/43_delete_application.png)

---

**Delete Namespaces and Destroy Infrastructure:**   
After the ArgoCD applications are removed, manually delete the application namespaces to ensure all cloud load balancers are deprovisioned before running Terraform destroy for resource clean-up:   

```
kubectl get namespace
kubectl delete ns <application_namespace>       # repeat for all application namespaces
```

---

Next, clean up the ArgoCD CRDs that were installed by Helm. These are cluster-scoped resources that Terraform does not manage directly:

```
kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io
```

```
terraform destroy --auto-approve
```

---
![Figure 46 — kubectl delete crd: ArgoCD CRDs removed successfully](images/46_delete_argocd_related_crd.png)

---
![Figure 44 — Deleting staging namespaces and running terraform destroy --auto-approve on Staging-Infra](images/44_terraform_destroy.png)

---

Remember to switch context and delete resources for the other cluster as applicable. 

```
kubectl config use-context <context-name>
```

Use the same clean-up process as above.

---
![Figure 45 — Deleting dev namespaces and running terraform destroy --auto-approve on Dev-Infra](images/45_terraform_destroy.png)

---

**Quick Note:**   
If you are having issues cleaning all resources with terraform destroy, consider deleting resources manually to make sure you are not left with ghost resources in AWS. Since these are demo clusters, feel free to delete the nodes through the CLI and re-try the delete process.

```
kubectl get nodes
kubectl delete node <ip.node>       #   update as required

terraform destroy --auto-approve
```
---

**Outcome:**    
Both clusters and all associated AWS resources (VPCs, EKS clusters, node groups, load balancers, IAM roles) are fully destroyed, leaving no orphaned cloud resources and incurring no further cost.

## Summary   
This project demonstrates how a small investment in template-based thinking — parameterised builds, reusable modules, overlay-based configuration — eliminates nearly all manual work in a multi-environment Kubernetes deployment pipeline.   
The six steps map to a DRY-principle:   
•	Step 1: One parameterised build script produces all Docker image variants   
•	Step 2: One Kustomize base serves all environments via lightweight overlays   
•	Step 3: Shared Terraform modules provision the dev EKS cluster and ArgoCD in one command   
•	Step 4: The App of Apps pattern deploys all four applications from a single ArgoCD registration   
•	Step 5: The same Terraform modules provision staging; overlays automatically apply the correct replica count  
•	Step 6: Clean teardown leaves no orphaned cloud resources   

With this set-up, the total amount of unique configuration required to run four applications across two fully-provisioned Kubernetes clusters is remarkably small. Most of the configuration has been improved to enable re-useability and automation

## Next Steps — Extending the Demo   
This project establishes a solid foundation. The patterns it introduces — reusable modules, overlay-based configuration, and GitOps reconciliation — are designed to be extended. Below are the most impactful directions to take it further. Let me know which direction you decide to take including pathways not listed below:   

### 1. Integrate a CI/CD Pipeline   
Currently the Docker images are built and pushed manually. The natural next step is to trigger that process automatically on every code change. A CI pipeline (GitHub Actions, GitLab CI, or Jenkins) would:  
•	Run on every push to main or a release tag  
•	Execute build.sh to build all four images  
•	Tag each image with the Git commit SHA (e.g. ucheor/argocd-trf-k8s-demo-blue:abc1234)  
•	Push the images to Docker Hub (or ECR)  
•	Update the newTag field in each overlay's kustomization.yaml to the new SHA  
•	Commit and push the manifest change back to the repository  
ArgoCD detects the manifest change and rolls out the new image version automatically. This closes the loop: a code commit triggers a build, which triggers a manifest update, which triggers a deployment — with no human intervention and a full audit trail in Git.   

**Tool recommendation:** GitHub Actions with the official docker/build-push-action and a kustomize edit set image step is the fastest path to a working pipeline for this project structure.   

### 2. Add Automated Image Scanning   
Before pushing images to a registry, integrate a vulnerability scanner such as Trivy or Grype as a CI step. Configure the pipeline to fail if critical CVEs are found, ensuring that only clean images ever reach the registry and therefore the cluster.   

### 3. Add Horizontal Pod Autoscaling   
The Kustomize overlays already control replica counts. Replace static replica values with a HorizontalPodAutoscaler resource in each base, and use overlays to set per-environment min/max replica bounds and CPU target thresholds. The staging overlay might allow scaling up to 10 replicas under load while dev stays capped at 2.   


## Tech Stack   
Every tool in this project was chosen because it solves a specific automation problem and composes cleanly with the others.   

**Image**   
- **Docker** — single parameterised `Dockerfile` + `build.sh` builds all variants via `--build-arg`   
- **Docker Hub** — public registry; no-auth pulls, swap for ECR in private workloads   

**Infrastructure**   
- **Terraform** — modules for VPC, EKS, and ArgoCD written once, called per environment.Providers: `aws` v6.30, `kubernetes` v2.35, `helm` v2.17   
- **Amazon EKS** — managed Kubernetes 1.31 on `t3.medium` nodes   
- **Amazon VPC & ELB** — private subnets for nodes, public for ALBs, fully automated by the vpc module   
- **Amazon S3** — remote Terraform state, per-environment keys, lock file enabled   

**GitOps & Deployment**   
- **ArgoCD** v2.13.0 — GitOps controller installed via Helm at cluster creation; App of Apps pattern manages all child apps from one registration   
- **Kustomize** — base/overlay pattern; dev vs staging differences declared in overlays only; built into `kubectl` and ArgoCD natively   

**Tooling**   
- **VS Code** — Terraform, YAML, Kubernetes extensions   
- **kubectl / AWS CLI** — cluster inspection, namespace management, kubeconfig updates   
- **Git / GitHub** — single source of truth; every commit is a deployment instruction   
