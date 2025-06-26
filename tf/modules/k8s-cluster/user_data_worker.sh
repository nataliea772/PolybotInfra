#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -e

# Set hostname
hostnamectl set-hostname worker-node

# Wait for cloud-init to complete
sleep 30

# Set Kubernetes version
KUBERNETES_VERSION=v1.32

# Install required tools
apt-get update
apt-get install -y jq unzip ebtables ethtool curl

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

export PATH=$PATH:/usr/local/bin  # Add AWS CLI to path explicitly for this script

# Enable IP forwarding
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sysctl --system

# Add Kubernetes and cri-o repositories
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | tee /etc/apt/sources.list.d/cri-o.list

apt-get update
apt-get install -y software-properties-common apt-transport-https ca-certificates gpg
apt-get install -y cri-o kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Start services
systemctl enable --now crio
systemctl enable --now kubelet

# Disable swap
swapoff -a
(crontab -l ; echo "@reboot /sbin/swapoff -a") | crontab -

# Fetch join command from SSM
echo "🕒 Fetching kubeadm join command..."
JOIN_CMD=$(aws ssm get-parameter \
  --region us-west-1 \
  --name "/polybot/k8s/join-command" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text)

# Execute the join command
echo "➡️  Executing: $JOIN_CMD"
$JOIN_CMD

echo "✅ Worker node setup complete!"
