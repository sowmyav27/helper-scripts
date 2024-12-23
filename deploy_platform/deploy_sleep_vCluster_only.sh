#!/bin/bash

set -e

CONFIG_FILE="vcluster-config.yaml"

read -p "Enter the vCluster version to install (default: 4.1.1): " INPUT_VCLUSTER_PLATFORM_VERSION
VCLUSTER_PLATFORM_VERSION=${INPUT_VCLUSTER_PLATFORM_VERSION:-4.1.1}

echo "Starting vCluster platform..."
vcluster platform start --version=$VCLUSTER_PLATFORM_VERSION

echo "Creating configuration file: $CONFIG_FILE..."
cat <<EOF > $CONFIG_FILE
experimental:
  sleepMode:
    enabled: true
    autoSleep:
      afterInactivity: 20s
      exclude: # exclude entire workloads
        selector: 
          labels:
            dont: sleep
EOF

VCLUSTER_NAME="vcluster-$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)"
echo "Deploying vCluster: $VCLUSTER_NAME..."
vcluster create $VCLUSTER_NAME --values=$CONFIG_FILE
echo "vCluster $VCLUSTER_NAME deployed successfully."
vcluster disconnect
