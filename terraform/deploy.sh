#!/bin/bash
set -eo pipefail

while getopts "k:h:" opt; do
  case $opt in
    k) ACCESS_KEY="$OPTARG" ;;
    h) HOSTNAME="$OPTARG" ;;
    *) echo "Usage: $0 -k <access_key> -h <hostname>"; exit 1 ;;
  esac
done

if [ -z "$ACCESS_KEY" ] || [ -z "$HOSTNAME" ]; then
  echo "Missing required arguments!"
  exit 1
fi

# Run Terraform to create resources and capture the generated name
terraform init
terraform apply -auto-approve \
  -var="platform_access_key=$ACCESS_KEY" \
  -var="platform_hostname=$HOSTNAME"

VCLUSTER_NAME=$(terraform output -raw vcluster_name)

# Patch vcluster.yaml with the generated namespace
sed "s/\${NAMESPACE}/$VCLUSTER_NAME/g" vcluster.yaml > vcluster.generated.yaml

# (Optional) Re-run helm with the patched values if needed, or ensure the helm_release uses the correct file

echo -e "\n\033[1;32mDeployment Verification:\033[0m"
kubectl get ns "$VCLUSTER_NAME"
kubectl get secret -n "$VCLUSTER_NAME" vcluster-platform-api-key

echo -e "\n\033[1;34mAccess Your vCluster:\033[0m"
echo "vcluster connect $VCLUSTER_NAME --namespace $VCLUSTER_NAME"
