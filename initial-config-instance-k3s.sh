#!/bin/bash


# Installing k3s
echo "Installing k3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.31.2+k3s1 sh -
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Installing Helm
echo "Installing Helm..."
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm -y

# Installing kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# install k9s
wget https://github.com/derailed/k9s/releases/download/v0.32.5/k9s_linux_amd64.deb
sudo apt install ./k9s_linux_amd64.deb

# Add aliases and environment variables to ~/.zshrc
echo "Updating ~/.zshrc with aliases and PATH..."
{
    echo ""
    echo "# Custom aliases for vCluster and kubectl"
    echo "alias k='kubectl'"
    echo "alias vd='vcluster delete'"
    echo "alias vv='vcluster --version'"
    echo "alias vc='vcluster create'"
    echo "alias vl='vcluster list'"
    echo "alias vdis='vcluster disconnect'"
    echo "alias vps='vcluster platform start'"
} >> ~/.zshrc

# Source the updated ~/.zshrc
echo "Sourcing ~/.zshrc..."
source ~/.zshrc

echo "Installing vCluster CLI..."
curl -L -o vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-amd64" && sudo install -c -m 0755 vcluster /usr/local/bin && rm -f vcluster


