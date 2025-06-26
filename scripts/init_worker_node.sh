#!/bin/bash
set -e

# === Fetch the kubeadm join command from SSM ===
echo "📦 Fetching join command from SSM..."

JOIN_CMD=$(aws ssm get-parameter \
  --name "/polybot/k8s/join-command" \
  --with-decryption \
  --region us-west-1 \
  --query "Parameter.Value" \
  --output text)

echo "🚀 Running join command..."
sudo $JOIN_CMD
