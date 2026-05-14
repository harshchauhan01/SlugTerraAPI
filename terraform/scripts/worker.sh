#!/bin/bash

set -euxo pipefail

LOG_FILE="/var/log/worker-bootstrap.log"

exec > >(tee -a $LOG_FILE) 2>&1

echo "========== STARTING WORKER SETUP =========="

export DEBIAN_FRONTEND=noninteractive

# Template variables provided by Terraform: TERRAFORM_MASTER_IP, TERRAFORM_AWS_REGION

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
# Wait For Join Command In SSM
# ---------------------------------------------------

echo "Waiting for join command from SSM in region TERRAFORM_AWS_REGION..."

until aws ssm get-parameter \
  --name "/k8s/join-command" \
  --query "Parameter.Value" \
  --output text \
  --region TERRAFORM_AWS_REGION \
  > /tmp/join-command.sh
do
  echo "Join command not available yet..."
  sleep 15
done

echo "Join command fetched successfully"

# ---------------------------------------------------
# Validate reachability to API server and wait for stability
# ---------------------------------------------------

echo "Checking connectivity to master API at TERRAFORM_MASTER_IP:6443"
for i in {1..30}; do
  if curl -sk https://TERRAFORM_MASTER_IP:6443/version >/dev/null 2>&1; then
    echo "API reachable on attempt ${i}"
    break
  fi
  echo "API not reachable yet (attempt ${i}/30), waiting..."
  sleep 6
done

# Additional wait to ensure API server is fully ready for join requests
echo "Waiting 60 seconds for API server to stabilize..."
sleep 60

# ---------------------------------------------------
# Join Kubernetes Cluster (with retries and longer backoff)
# ---------------------------------------------------

JOIN_CMD=$(cat /tmp/join-command.sh)

echo "Join command: ${JOIN_CMD}"

attempt=0
max_attempts=8
while [ ${attempt} -lt ${max_attempts} ]; do
  attempt=$((attempt+1))
  echo "Attempt ${attempt}/${max_attempts} to join cluster"
  set +e
  bash -c "${JOIN_CMD}" && joined=0 || joined=$?
  set -e
  if [ "${joined}" = "0" ]; then
    echo "Joined cluster successfully"
    break
  fi
  
  if [ ${attempt} -lt ${max_attempts} ]; then
    sleep_time=$((attempt * 20))
    echo "kubeadm join failed with exit ${joined}, retrying in ${sleep_time}s..."
    sleep ${sleep_time}
  fi
done

if [ "${joined}" != "0" ]; then
  echo "Failed to join cluster after ${max_attempts} attempts" >&2
  echo "Dumping kubeadm version and node info for debugging:"
  kubeadm version || true
  echo "---"
  exit 1
fi

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

systemctl status kubelet --no-pager || true

echo "========== WORKER SETUP COMPLETED =========="