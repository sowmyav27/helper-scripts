#!/bin/bash
set -eo pipefail

if [ -z "$1" ]; then
  read -p "Enter vCluster platform API key " ACCESS_KEY
else
  ACCESS_KEY="$1"
fi

if [ -z "$2" ]; then
  read -p "Host Name: " HOSTNAME
else
  HOSTNAME="$2"
fi

if [ -z "$3" ]; then
  read -p "VCLUSTER Namespace: " VCLUSTER_NAMESPACE
else
  VCLUSTER_NAMESPACE="$3"
fi

if [ -z "$4" ]; then
  read -p "VCLUSTER Name: " VCLUSTER_NAME
else
  VCLUSTER_NAME="$4"
fi

if [ -z "$5" ]; then
  read -p "VCLUSTER Version: (Example: 0.25.1, 0.26.0-alpha.18) " VCLUSTER_VERSION
else
  VCLUSTER_VERSION="$5"
fi


# Run Terraform to create resources and capture the generated name
terraform init
terraform apply -auto-approve \
  -var="platform_access_key=$ACCESS_KEY" \
  -var="platform_hostname=$HOSTNAME" \
  -var="vcluster_namespace=$VCLUSTER_NAMESPACE" \
  -var="vcluster_name=$VCLUSTER_NAME" \
  -var="vcluster_version=$VCLUSTER_VERSION" \


echo "Connect to vCluster"
vcluster connect $VCLUSTER_NAME -n $VCLUSTER_NAMESPACE
