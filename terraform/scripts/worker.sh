#!/bin/bash

set -euxo pipefail

LOG_FILE="/var/log/worker-bootstrap.log"

exec > >(tee -a $LOG_FILE) 2>&1

echo "========== STARTING WORKER SETUP =========="

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------
# System Update
# ---------------------------------------------------

apt-get update -y

apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  software-properties-common \
  awscli

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
# Sysctl
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
# ---------------------------------------------------

sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
/etc/containerd/config.toml

# ---------------------------------------------------
# Start containerd
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

echo "containerd is active"

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

systemctl enable kubelet
systemctl restart kubelet

# ---------------------------------------------------
# Wait For Join Command In SSM
# ---------------------------------------------------

echo "Waiting for join command from SSM..."

until aws ssm get-parameter \
  --name "/k8s/join-command" \
  --query "Parameter.Value" \
  --output text \
  --region us-east-1 \
  > /tmp/join-command.sh
do
  echo "Join command not available yet..."
  sleep 15
done

echo "Join command fetched successfully"

# ---------------------------------------------------
# Join Kubernetes Cluster
# ---------------------------------------------------

JOIN_CMD=$(cat /tmp/join-command.sh)

echo "Executing join command..."

$JOIN_CMD

# ---------------------------------------------------
# Wait For kubelet
# ---------------------------------------------------

timeout 120 bash -c \
'until systemctl is-active --quiet kubelet; do
  echo "Waiting for kubelet..."
  sleep 10
done'

echo "kubelet is active"

# ---------------------------------------------------
# Validation
# ---------------------------------------------------

systemctl status kubelet --no-pager

echo "========== WORKER SETUP COMPLETED =========="