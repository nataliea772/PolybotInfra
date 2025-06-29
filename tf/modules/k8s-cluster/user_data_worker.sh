#!/bin/bash
set -e

KUBERNETES_VERSION=v1.32
REGION="us-west-1"

# Set unique hostname
hostnamectl set-hostname "natalie-worker-$(date +%s)"

# Update system and install base dependencies
apt-get update
apt-get install -y jq unzip ebtables ethtool curl gnupg lsb-release ca-certificates apt-transport-https software-properties-common

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
export PATH=$PATH:/usr/local/bin

# Add keyrings directory
mkdir -p /etc/apt/keyrings

# Add Kubernetes repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

# Add CRI-O repo
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" \
  > /etc/apt/sources.list.d/cri-o.list

# Install Kubernetes components and container runtime
apt-get update
apt-get install -y cri-o kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Enable and start required services
systemctl daemon-reexec
systemctl enable --now crio
systemctl enable --now kubelet

# Disable swap
sed -i.bak '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a
(crontab -l ; echo "@reboot /sbin/swapoff -a") | crontab -

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-kubernetes-cri.conf
sysctl --system

# Wait for the join command from SSM
MAX_RETRIES=30
RETRY_DELAY=10

for i in $(seq 1 $MAX_RETRIES); do
  echo "Attempt $i: Fetching join command from SSM..."
  JOIN_COMMAND=$(aws ssm get-parameter \
    --name "/k8s/worker-join-command" \
    --region $REGION \
    --with-decryption \
    --query "Parameter.Value" \
    --output text) && break
  echo "Join command not yet available. Retrying in $RETRY_DELAY seconds..."
  sleep $RETRY_DELAY
done

if [ -z "$JOIN_COMMAND" ]; then
  echo "❌ Failed to retrieve join command"
  exit 1
fi

# Join the Kubernetes cluster
echo "🛠️ Running kubeadm join..."
$JOIN_COMMAND
