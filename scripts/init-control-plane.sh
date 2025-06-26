#!/bin/bash
set -e

echo "📦 Starting control-plane initialization..."

# initialize only id not already done
if [ ! -f /etc/kubernetes/admin.conf ]; then
  echo "🔧 Initializing Kubernetes cluster..."
  sudo kubeadm init --pod-network-cidr=192.168.0.0/16 | tee /tmp/kubeadm-init.log
fi

echo "🔧 Configuring kubectl for current user..."
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


if ! kubectl get pods -n kube-system | grep -q calico; then
  echo "🌐 Installing Calico CNI..."
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
fi

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

echo "🕒 Setting up cron job to refresh kubeadm join token..."

cat <<'EOF' | sudo tee /etc/cron.d/refresh-join-token
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

*/30 * * * * root /usr/local/bin/refresh-join-token.sh
EOF

cat <<'EOF' | sudo tee /usr/local/bin/refresh-join-token.sh
#!/bin/bash
set -e

JOIN_CMD=$(kubeadm token create --print-join-command)
aws ssm put-parameter \
  --name "/polybot/k8s/join-command" \
  --type "SecureString" \
  --value "$JOIN_CMD" \
  --overwrite \
  --region us-west-1
EOF

chmod +x /usr/local/bin/refresh-join-token.sh
systemctl restart cron || systemctl restart crond || echo "Cron service restart failed"

