#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-kind}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-slugterra}"
LOCAL_IMAGE_NAME="${LOCAL_IMAGE_NAME:-slugterra-api:local}"
BUILD_LOCAL_IMAGE="${BUILD_LOCAL_IMAGE:-true}"
IMAGE_URI="${IMAGE_URI:-}"
TERRAFORM_AUTO_APPLY="${TERRAFORM_AUTO_APPLY:-false}"
SKIP_MONITORING="${SKIP_MONITORING:-false}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

apply_manifests() {
  kubectl apply -f k8s/namespace.yml
  kubectl apply -f k8s/configmap.yml
  kubectl apply -f k8s/secret.yml
  kubectl apply -f k8s/postgres.yml
  kubectl apply -f k8s/redis.yml
  kubectl apply -f k8s/service.yml
  kubectl apply -f k8s/ingress.yml
  kubectl apply -f k8s/deployment.yml
  kubectl apply -f k8s/hpa.yml

  if [[ "${SKIP_MONITORING}" != "true" ]]; then
    kubectl apply -f k8s/monitoring/namespace.yml
    kubectl apply -f k8s/monitoring/
  fi
}

rollout_check() {
  kubectl -n slugapi-ns rollout status deployment/slugapp --timeout=180s
  kubectl get deploy,svc,ingress,hpa -n slugapi-ns
}

setup_kind_ingress() {
  if ! kubectl get namespace ingress-nginx >/dev/null 2>&1; then
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
  fi
}

run_kind() {
  require_cmd kind
  require_cmd kubectl
  require_cmd docker

  if ! kind get clusters | grep -qx "${KIND_CLUSTER_NAME}"; then
    kind create cluster --name "${KIND_CLUSTER_NAME}" --config kind-cluster/kind-config.yml
  fi

  setup_kind_ingress

  if [[ "${BUILD_LOCAL_IMAGE}" == "true" ]]; then
    docker build -f docker/Dockerfile --target production -t "${LOCAL_IMAGE_NAME}" .
  fi

  kind load docker-image "${LOCAL_IMAGE_NAME}" --name "${KIND_CLUSTER_NAME}"

  apply_manifests
  kubectl -n slugapi-ns set image deployment/slugapp slugapp="${LOCAL_IMAGE_NAME}"
  rollout_check

  echo "Kind deployment completed."
  echo "Access app: http://127.0.0.1/"
}

# EKS deployment removed in free-tier conversion; use EC2 or kind instead.

case "${TARGET}" in
  kind)
    run_kind
    ;;
  *)
    echo "Unsupported target '${TARGET}'. Use 'kind'." >&2
    exit 1
    ;;
esac
