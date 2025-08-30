#!/usr/bin/env bash
set -e

echo "[CI/CD] Installing Jenkins, k3s, ArgoCD, and Gitea..."

### -----------------------------
### Jenkins
### -----------------------------
echo "[CI/CD] Installing Jenkins..."
sudo apt-get update
sudo apt-get install -y openjdk-11-jdk curl gnupg2

wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo apt-key add -
echo "deb https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list
sudo apt-get update
sudo apt-get install -y jenkins
sudo systemctl enable jenkins --now
echo "[CI/CD] Jenkins running on :8080 "


### -----------------------------
### k3s (lightweight k8s)
### -----------------------------
if ! command -v k3s >/dev/null 2>&1; then
  echo "[CI/CD] Installing k3s..."
  curl -sfL https://get.k3s.io | sh -
  sudo systemctl enable k3s --now
fi

# kubeconfig for vagrant user
mkdir -p /home/vagrant/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sudo chown vagrant:vagrant /home/vagrant/.kube/config
export KUBECONFIG=/home/vagrant/.kube/config

echo "[CI/CD] k3s installed "


### -----------------------------
### ArgoCD
### -----------------------------
echo "[CI/CD] Installing ArgoCD in k3s..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Port-forward for UI (optional)
kubectl -n argocd patch svc argocd-server -p '{"spec": {"type": "NodePort"}}' || true

echo "[CI/CD] ArgoCD deployed "


### -----------------------------
### Gitea (self-hosted Git)
### -----------------------------
echo "[CI/CD] Installing Gitea..."
sudo docker volume create gitea_data || true
sudo docker run -d --restart always --name=gitea \
  -p 3001:3000 -p 222:22 \
  -v gitea_data:/data \
  gitea/gitea:latest

echo "[CI/CD] Gitea running on :3001 (web) and :222 (ssh) "


echo "[CI/CD] All components installed: Jenkins, k3s, ArgoCD, Gitea "

