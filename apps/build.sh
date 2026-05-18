#!/bin/bash

declare -A themes=(
  ["blue"]="#1e3a5f,#a7c7e7,ArgoCD-TrF-K8s-Demo-Blue"
  ["orange"]="#e65100,#bf360c,ArgoCD-TrF-K8s-Demo-Orange"
  ["green"]="#00695c,#004d40,ArgoCD-TrF-K8s-Demo-Green"
  ["charcoal"]="#212121,#111111,ArgoCD-TrF-K8s-Demo-Charcoal"
)

for name in "${!themes[@]}"; do

  IFS=',' read -r primary secondary site_name <<< "${themes[$name]}"

  echo "Building $name image..."

  docker build \
    --build-arg PRIMARY_COLOR="$primary" \
    --build-arg SECONDARY_COLOR="$secondary" \
    --build-arg SITE_NAME="$site_name" \
    -t "argocd-trf-k8s-demo-$name" .

done

echo "Done!"

docker images | grep ArgoCD-TrF-K8s-Demo