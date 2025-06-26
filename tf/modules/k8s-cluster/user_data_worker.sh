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
sudo apt-get update
sudo apt-get install -y jq unzip ebtables ethtool

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Enable IP forwarding
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# Add Kubernetes and cri-o repositories
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

# Install packages
sudo apt-get update
sudo apt-get install -y software-properties-common apt-transport-https ca-certificates curl gpg
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Start services
sudo systemctl enable --now crio
sudo systemctl enable --now kubelet

# Disable swap
swapoff -a
(crontab -l ; echo "@reboot /sbin/swapoff -a") | crontab -


# Fetch join command from SSM Parameter Store
JOIN_CMD=$(aws ssm get-parameter \
  --region us-west-1 \
  --name "/polybot/k8s/join-command" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text)

# Run the join command
echo "Running join command: $JOIN_CMD"
sudo $JOIN_CMD

echo "✅ user_data_worker.sh completed."
