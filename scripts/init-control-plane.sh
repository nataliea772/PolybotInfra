#!/bin/bash
set -e

if [ ! -f /etc/kubernetes/admin.conf ]; then
  echo "🔧 Initializing Kubernetes cluster..."
  sudo kubeadm init --pod-network-cidr=192.168.0.0/16
fi

echo "🔧 Configuring kubectl for current user..."
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "⏳ Waiting for Kubernetes API server to become available..."
for i in {1..30}; do
  if kubectl get nodes &> /dev/null; then
    echo "✅ API server is up!"
    break
  else
    echo "Waiting for API server..."
    sleep 10
  fi
done

if ! kubectl get pods -n kube-system | grep -q calico; then
  echo "🌐 Installing Calico CNI..."
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
fi

echo "✅ Control plane initialization completed."

echo "📦 Saving kubeadm join command to SSM... (for worker node)"
JOIN_CMD=$(kubeadm token create --print-join-command)

echo "AWS CLI version:" && aws --version

aws ssm put-parameter \
  --name "/polybot/k8s/join-command" \
  --type "SecureString" \
  --value "$JOIN_CMD" \
  --overwrite \
  --region us-west-1

echo "✅ Join command saved to SSM."
