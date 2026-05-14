#!/bin/bash

set -euxo pipefail

LOG_FILE="/var/log/master-bootstrap.log"

exec > >(tee -a $LOG_FILE) 2>&1

echo "========== STARTING MASTER SETUP =========="

export DEBIAN_FRONTEND=noninteractive

# Template variable provided by Terraform: TERRAFORM_AWS_REGION

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
  unzip

# Install AWS CLI v2
if ! command -v aws >/dev/null 2>&1; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip -o /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install || true
fi

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
# Initialize Kubernetes Cluster
# ---------------------------------------------------

kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --ignore-preflight-errors=NumCPU

# ---------------------------------------------------
# Configure kubectl
# ---------------------------------------------------

mkdir -p /home/ubuntu/.kube

cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config

chown ubuntu:ubuntu /home/ubuntu/.kube/config

export KUBECONFIG=/home/ubuntu/.kube/config

# ---------------------------------------------------
# Wait For API Server
# ---------------------------------------------------

timeout 120 bash -c \
'until kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes; do
  echo "Waiting for Kubernetes API..."
  sleep 10
done'

echo "Kubernetes API is ready"

# Give the API server a few more seconds to stabilize internal components
sleep 30

# ---------------------------------------------------
# Install Calico
# ---------------------------------------------------

su - ubuntu -c "
kubectl apply -f \
https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
"

# Give Calico time to initialize
sleep 15

# ---------------------------------------------------
# Helper: retry function
# ---------------------------------------------------
retry() {
  local -r -i max_attempts=${1:-6}; shift
  local -r cmd=("$@")
  local -i attempt=1
  local sleep_time=5
  until "${cmd[@]}"; do
    if (( attempt >= max_attempts )); then
      echo "Command failed after ${attempt} attempts: ${cmd[*]}" >&2
      return 1
    fi
    echo "Command failed, retrying in ${sleep_time}s..." >&2
    sleep ${sleep_time}
    attempt=$(( attempt + 1 ))
    sleep_time=$(( sleep_time * 2 ))
  done
}

# ---------------------------------------------------
# Generate Join Command
# ---------------------------------------------------

echo "Generating join command..."

JOIN_CMD=$(kubeadm token create --print-join-command)

echo "Join command generated: ${JOIN_CMD}"

echo "${JOIN_CMD}" > /home/ubuntu/join.sh

chmod +x /home/ubuntu/join.sh

chown ubuntu:ubuntu /home/ubuntu/join.sh

# ---------------------------------------------------
# Store Join Command In AWS SSM (with retries)
# ---------------------------------------------------

echo "Storing join command to SSM in region TERRAFORM_AWS_REGION"

retry 8 aws ssm put-parameter \
  --name "/k8s/join-command" \
  --value "${JOIN_CMD}" \
  --type "String" \
  --overwrite \
  --region TERRAFORM_AWS_REGION

echo "Join command stored in SSM"

# ---------------------------------------------------
# Validation
# ---------------------------------------------------

kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes || true

kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -A || true

echo "========== MASTER SETUP COMPLETED =========="