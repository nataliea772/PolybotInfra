#!/bin/bash
set -e

if [ ! -f /etc/kubernetes/admin.conf ]; then
  echo "🔧 Initializing Kubernetes cluster..."
  sudo kubeadm init --pod-network-cidr=192.168.0.0/16
fi

echo "🔧 Configuring kubectl for current user..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

if ! kubectl get pods -n kube-system | grep -q calico; then
  echo "🌐 Installing Calico CNI..."
  sudo kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
fi

echo "✅ Control plane initialization completed."
