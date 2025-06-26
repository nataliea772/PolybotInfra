#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -e

# Set hostname
hostnamectl set-hostname control-plane

# Wait for cloud-init
sleep 30

# These instructions are for Kubernetes v1.32.
KUBERNETES_VERSION=v1.32

sudo apt-get update
sudo apt-get install jq unzip ebtables ethtool -y

# install awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Enable IPv4 packet forwarding
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Install cri-o, kubelet, kubeadm, kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update
sudo apt-get install -y software-properties-common apt-transport-https ca-certificates curl gpg
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Start services
sudo systemctl start crio.service
sudo systemctl enable --now crio.service
sudo systemctl enable --now kubelet

# Disable swap
swapoff -a
(crontab -l ; echo "@reboot /sbin/swapoff -a") | crontab -

# ✅ Final logging for verification
echo "✅ user_data.sh completed."

echo "🔍 kubeadm version:"
kubeadm version || echo "❌ kubeadm NOT installed"

echo "🔍 aws version:"
aws --version || echo "❌ AWS CLI NOT installed"
