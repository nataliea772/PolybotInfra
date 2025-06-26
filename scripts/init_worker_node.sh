#!/bin/bash
set -e

echo "📦 Fetching join command from SSM..."

JOIN_CMD=$(aws ssm get-parameter \
  --name "/k8s/worker-join-command" \
  --with-decryption \
  --region us-west-1 \
  --query "Parameter.Value" \
  --output text)

echo "🧹 Resetting kubeadm to clean state (if needed)..."
sudo kubeadm reset -f || true
sudo systemctl restart kubelet

echo "🚀 Running join command..."
sudo $JOIN_CMD
