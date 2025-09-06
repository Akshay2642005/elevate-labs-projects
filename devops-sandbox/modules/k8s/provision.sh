#!/bin/bash
set -e

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# --- Install dependencies ---
log "[+] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq curl apt-transport-https ca-certificates gnupg lsb-release jq

# --- Install K3s with traefik/servicelb disabled ---
log "[+] Installing K3s (traefik/servicelb disabled)..."
/usr/local/bin/k3s-uninstall.sh >/dev/null 2>&1 || true
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik --disable servicelb" sh -

sudo chmod 666 /etc/rancher/k3s/k3s.yaml
sudo install -D /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sudo cp /etc/rancher/k3s/k3s.yaml /vagrant/config
# --- Wait for K3s API to be ready ---
log "[+] Waiting for K3s API server to become ready..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
until kubectl get nodes >/dev/null 2>&1; do
  sleep 3
done
kubectl wait --for=condition=Ready node --all --timeout=300s

# --- Install Helm ---
log "[+] Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# --- Detect VM subnet and prepare MetalLB IP pool ---
VM_IP=$(hostname -I | awk '{print $2}')
SUBNET=$(echo "$VM_IP" | cut -d. -f1-3)
POOL_START="${SUBNET}.240"
POOL_END="${SUBNET}.250"

log "[+] VM IP=${VM_IP} → MetalLB pool=${POOL_START}-${POOL_END}"

# --- Install MetalLB ---
log "[+] Installing MetalLB..."
kubectl create namespace metallb-system --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml

# --- Wait for MetalLB pods ---
kubectl rollout status -n metallb-system deployment/controller --timeout=300s

# --- Apply MetalLB IPAddressPool ---
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-address-pool
  namespace: metallb-system
spec:
  addresses:
  - ${POOL_START}-${POOL_END}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2adv
  namespace: metallb-system
spec: {}
EOF

# --- Install Traefik via Helm ---
log "[+] Installing Traefik via Helm..."
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik -n traefik --create-namespace

log "[✓] Provisioning complete!"


