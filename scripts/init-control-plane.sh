#!/bin/bash

# === CONFIG ===
USER=ubuntu
INSTANCE_IP=$(terraform output -raw control_plane_public_ip)
KEY_PATH=~/.ssh/natalie_key2.pem

# === INIT COMMANDS ===
INIT_COMMANDS=$(cat <<'END'
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
END
)

echo "Connecting to $INSTANCE_IP..."
ssh -i $KEY_PATH $USER@$INSTANCE_IP "$INIT_COMMANDS"
