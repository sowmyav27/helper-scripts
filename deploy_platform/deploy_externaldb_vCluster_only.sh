#!/bin/bash

set -e

CONFIG_FILE="vcluster-config.yaml"
SHARED_CONNECTOR_SECRET="mysql-connector.yaml"

read -p "Enter the vCluster version to install (default: 4.1.1): " INPUT_VCLUSTER_PLATFORM_VERSION
VCLUSTER_PLATFORM_VERSION=${INPUT_VCLUSTER_PLATFORM_VERSION:-4.1.1}

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

VCLUSTER_NAME="vcluster-$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)"
echo "Deploying vCluster: $VCLUSTER_NAME..."
vcluster create $VCLUSTER_NAME --values=$CONFIG_FILE
echo "vCluster $VCLUSTER_NAME deployed successfully."
vcluster disconnect
