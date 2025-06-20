#!/bin/bash

if [ -z "$1" ]; then
  read -p "Enter k8sversion. Ex: 1.32.1: " K8S_VERSION
else
  K8S_VERSION="$1"
fi

if [ -z "$2" ]; then
  read -p "Enter Cluster node count: " NODES_COUNT
else
  NODES_COUNT="$2"
fi
if [ -z "$3" ]; then
  read -p "Enter vCluster CLI version. Ex: v0.25.0, v0.26.0-alpha.12: " VCLUSTER_VERSION
else
  VCLUSTER_VERSION="$3"
fi


if ! command -v kubectl &> /dev/null; then
    echo "kubectl not found, installing..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
else
    echo "kubectl is already installed, skipping installation."
fi


if ! command -v minikube &> /dev/null; then
    echo "Minikube not found, installing..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
else
    echo "Minikube is already installed, skipping installation."
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo "Docker not found, installing..."
  # Install Docker
  sudo apt update
  sudo apt install -y docker.io
else
  echo "Docker is already installed, skipping installation."
fi

# Check if Go is installed
if ! command -v go &> /dev/null; then
  echo "Go not found, installing..."
  # Install Go
  sudo apt update
  sudo apt install -y golang
  export PATH=$PATH:$(go env GOPATH)/bin
else
  echo "Go is already installed, skipping installation."
fi

# Install Sonobuoy (if not already installed)
if ! command -v sonobuoy &> /dev/null; then
    echo "Installing Sonobuoy..."
    SONOBUOY_VERSION=$(curl -s https://api.github.com/repos/vmware-tanzu/sonobuoy/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -L "https://github.com/vmware-tanzu/sonobuoy/releases/download/${SONOBUOY_VERSION}/sonobuoy_${SONOBUOY_VERSION#v}_linux_amd64.tar.gz" -o sonobuoy.tar.gz
    tar -xzf sonobuoy.tar.gz
    sudo mv sonobuoy /usr/local/bin/
    sonobuoy version
fi

# Start Minikube with specified Kubernetes version and node count
minikube start --kubernetes-version $K8S_VERSION --nodes=$NODES_COUNT --force

curl -L -o vcluster "https://github.com/loft-sh/vcluster/releases/download/${VCLUSTER_VERSION}/vcluster-linux-amd64" && sudo install -c -m 0755 vcluster /usr/local/bin && rm -f vcluster

# Create a values.yaml file for vCluster
cat <<EOF > values.yaml
controlPlane:
  advanced:
    virtualScheduler:
      enabled: true
  backingStore:
    etcd:
      deploy:
        enabled: true
        statefulSet:
          image:
            tag: 3.5.17-0
  distro:
    k8s:
      image:
        tag: v1.32.1
      apiServer:
        extraArgs:
          - --service-account-jwks-uri=https://kubernetes.default.svc.cluster.local/openid/v1/jwks
      enabled: true
  statefulSet:
    scheduling:
      podManagementPolicy: OrderedReady

networking:
  advanced:
    proxyKubelets:
      byHostname: false
      byIP: false

sync:
  fromHost:
    csiDrivers:
      enabled: false
    csiStorageCapacities:
      enabled: false
    nodes:
      enabled: true
      selector:
        all: true
  toHost:
    persistentVolumes:
      enabled: true
    priorityClasses:
      enabled: true
    storageClasses:
      enabled: true
EOF


# Create the vCluster
vcluster create vcluster -n vcluster -f values.yaml --distro=k8s

# Run Sonobuoy with certified conformance mode
sonobuoy run --mode=certified-conformance --dns-pod-labels=k8s-app=vcluster-kube-dns
#sonobuoy run --mode=conformance-lite --dns-pod-labels=k8s-app=vcluster-kube-dns

# Periodically check Sonobuoy status
echo "Checking Sonobuoy status every 10 minutes..."
while true; do
    status=$(sonobuoy status)
    echo "$status"
    if echo "$status" | grep -q "complete"; then
        echo "Sonobuoy test completed."
        break
    else
        echo "Sonobuoy still running. Next check in 10 minutes..."
        sleep 600  # Wait for 10 minutes before checking again
    fi
done

# Retrieve results
echo "Retrieving Sonobuoy results..."
outfile=$(sonobuoy retrieve)
mkdir ./results; tar xzf $outfile -C ./results
cat results/plugins/e2e/results/global/e2e.log
