#!/bin/bash

set -euxo pipefail

LOG_FILE="/var/log/k8s-bootstrap.log"

exec > >(tee -a ${LOG_FILE}) 2>&1

echo "========== STARTING COMMON SETUP =========="

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------
# Update System
# ---------------------------------------------------

apt-get update -y

apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  software-properties-common

# ---------------------------------------------------
# Disable Swap
# ---------------------------------------------------

swapoff -a

sed -i '/ swap / s/^/#/' /etc/fstab

# ---------------------------------------------------
# Kernel Modules
# ---------------------------------------------------

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# ---------------------------------------------------
# Sysctl Settings
# ---------------------------------------------------

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# ---------------------------------------------------
# Install containerd
# ---------------------------------------------------

apt-get install -y containerd

mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml

# ---------------------------------------------------
# IMPORTANT FIX
# Kubernetes requires SystemdCgroup=true
# ---------------------------------------------------

sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
/etc/containerd/config.toml

# ---------------------------------------------------
# Restart containerd
# ---------------------------------------------------

systemctl daemon-reexec
systemctl daemon-reload

systemctl enable containerd
systemctl restart containerd

# ---------------------------------------------------
# Wait for containerd
# ---------------------------------------------------

timeout 60 bash -c \
'until systemctl is-active --quiet containerd; do
  echo "Waiting for containerd..."
  sleep 5
done'

echo "containerd is running"

# ---------------------------------------------------
# Kubernetes Repo
# ---------------------------------------------------

mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
| gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
| tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y

# ---------------------------------------------------
# Install Kubernetes Components
# ---------------------------------------------------

apt-get install -y \
  kubelet \
  kubeadm \
  kubectl

apt-mark hold kubelet kubeadm kubectl

# ---------------------------------------------------
# Enable kubelet
# ---------------------------------------------------

systemctl enable kubelet
systemctl restart kubelet

# ---------------------------------------------------
# Validation
# ---------------------------------------------------

echo "========== VALIDATING INSTALLATION =========="

containerd --version

kubeadm version

kubectl version --client

systemctl status containerd --no-pager

systemctl status kubelet --no-pager

echo "========== COMMON SETUP COMPLETED =========="