# Using helm from - docs: https://www.vcluster.com/docs/platform/administer/clusters/connect-cluster?x0=3 
#!/bin/bash

if [ -z "$1" ]; then
  read -p "Enter Connected Cluster Name: " CLUSTER_NAME
else
  CLUSTER_NAME="$1"
fi

if [ -z "$2" ]; then
  read -p "Enter Platform Host: " PLATFORM_HOST
else
  PLATFORM_HOST="$2"
fi

if [ -z "$3" ]; then
  read -p "Enter Kubeconfig file path of the cluster: " KUBECONFIG
else
  KUBECONFIG="$3"
fi


export ACCESS_KEY=$(vcluster platform access-key | jq -r .status.token)


cat <<EOF | kubectl apply -f -
apiVersion: management.loft.sh/v1
kind: Cluster
metadata:
  name: $CLUSTER_NAME
spec:
  displayName: $CLUSTER_NAME
  networkPeer: true
EOF

export PLATFORM_VERSION=$(curl -s "https://$PLATFORM_HOST/version" | jq -r '.version | .[0:]')

export CLUSTER_ACCESS_KEY=$(curl -s "https://$PLATFORM_HOST/kubernetes/management/apis/management.loft.sh/v1/clusters/$CLUSTER_NAME/accesskey" -H "Authorization: bearer $ACCESS_KEY")

if [[ -z "$CLUSTER_ACCESS_KEY" || "$CLUSTER_ACCESS_KEY" == "null" ]]; then
    echo "Error: Failed to retrieve Cluster Access Key. Check your access credentials and Loft Platform availability."
    exit 1
fi

helm upgrade loft loft --install \
  --repo https://charts.loft.sh/ \
  --version $PLATFORM_VERSION \
  --namespace loft \
  --create-namespace \
  --kubeconfig $KUBECONFIG \
  --set agentOnly=true \
  --set url=https://$PLATFORM_HOST \
  --set token=$(echo $CLUSTER_ACCESS_KEY | jq -r .accessKey) \
  --set additionalCA=$(echo $CLUSTER_ACCESS_KEY | jq -r .caCert) \
  --set insecure=$(echo $CLUSTER_ACCESS_KEY | jq -r .insecure)



#echo "Patch cluster with cluster.spec.managementNamespace: vcluster-platform"
#kubectl patch cluster $CLUSTER_NAME --type=merge -p '{"spec":{"managementNamespace":"vcluster-platform"}}'

echo "vCluster Loft agent installation completed successfully."
