#!/bin/bash
set -e

KUBERNETES_VERSION=v1.32

# Update and install dependencies
apt-get update
apt-get install -y jq unzip ebtables ethtool curl gnupg lsb-release ca-certificates apt-transport-https software-properties-common

# Add keyrings directory
mkdir -p /etc/apt/keyrings

# Add K8s and CRI-O repositories
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" \
  > /etc/apt/sources.list.d/cri-o.list

apt-get update
apt-get install -y cri-o kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Start services
systemctl enable --now crio
systemctl enable --now kubelet

# Disable swap
sed -i.bak '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a
(crontab -l ; echo "@reboot /sbin/swapoff -a") | crontab -

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-kubernetes-cri.conf
sysctl --system

# Fetch and run join command from SSM
REGION="us-west-1"
JOIN_COMMAND=$(aws ssm get-parameter \
  --name "/k8s/worker-join-command" \
  --region $REGION \
  --with-decryption \
  --query "Parameter.Value" \
  --output text)

$JOIN_COMMAND
