#!/bin/bash

set -e

CONFIG_FILE="vcluster-config.yaml"
SHARED_CONNECTOR_SECRET="mysql-connector.yaml"

read -p "Enter the vCluster version to install (default: 4.1.1): " INPUT_VCLUSTER_PLATFORM_VERSION
VCLUSTER_PLATFORM_VERSION=${INPUT_VCLUSTER_PLATFORM_VERSION:-4.1.1}

echo "Installing k3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.31.2+k3s1 sh -
mkdir ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config


echo "Installing Helm..."
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

echo "Installing vCluster CLI..."
curl -L -o vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-amd64" && sudo install -c -m 0755 vcluster /usr/local/bin && rm -f vcluster

echo "Starting vCluster platform..."
vcluster platform start --version=$VCLUSTER_PLATFORM_VERSION

echo "Installing mysql..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-mysql bitnami/mysql
MYSQL_PASSWORD=$(kubectl get secret --namespace default my-mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode)

cat <<EOF > $SHARED_CONNECTOR_SECRET
apiVersion: v1
kind: Secret
metadata:
  name: mysql-connector
  namespace: vcluster-platform
  labels:
    loft.sh/connector-type: "shared-database"
stringData:
  endpoint: "my-mysql.default.svc.cluster.local"
  password: "$MYSQL_PASSWORD"
  port: "3306"
  user: "root"
EOF

echo "Creating shared connector secret.."
kubectl apply -f $SHARED_CONNECTOR_SECRET

echo "Creating configuration file: $CONFIG_FILE..."
cat <<EOF > $CONFIG_FILE
controlPlane:
  backingStore:
    database:
      external:
        enabled: true
        connector: mysql-connector
EOF

VCLUSTER_NAME="test-$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)"
echo "Deploying vCluster: $VCLUSTER_NAME..."
vcluster create $VCLUSTER_NAME --values=$CONFIG_FILE
echo "vCluster $VCLUSTER_NAME deployed successfully."
vcluster disconnect
