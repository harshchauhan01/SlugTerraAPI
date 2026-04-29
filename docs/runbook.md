# Operations Runbook

## 1. Local Development
```bash
cp .env.example .env
docker compose up --build
```

## 2. Validate API Health
```bash
curl http://127.0.0.1:8000/api/slugs/
curl http://127.0.0.1:8000/metrics
```

## 3. CI/CD Pipeline Trigger
- Push a commit to the branch configured in Jenkins.
- Jenkins executes lint, bandit, tests, image build/push, terraform plan/apply, and Kubernetes deploy.

## 4. Unified Kubernetes Deployment

Run the same script with a target selector.

Local kind:

```bash
bash scripts/deploy.sh kind
```

EKS with Terraform apply:

```bash
export AWS_REGION=ap-south-1
export TERRAFORM_AUTO_APPLY=true
export IMAGE_URI=docker.io/<your-user>/slug-api:<tag>
bash scripts/deploy.sh eks
```

Manual fallback (if script is not used):

```bash
kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/configmap.yml
kubectl apply -f k8s/secret.yml
kubectl apply -f k8s/postgres.yml
kubectl apply -f k8s/redis.yml
kubectl apply -f k8s/service.yml
kubectl apply -f k8s/ingress.yml
kubectl apply -f k8s/deployment.yml
kubectl apply -f k8s/hpa.yml
kubectl apply -f k8s/monitoring/
```

## 5. Rollout Verification
```bash
kubectl get pods -n slugapi-ns
kubectl rollout status deployment/slugapp -n slugapi-ns
kubectl get hpa -n slugapi-ns
```

## 6. Monitoring Verification
```bash
kubectl port-forward -n monitoring service/prometheus 9090:9090
kubectl port-forward -n monitoring service/grafana 3000:3000
```
- Prometheus UI: http://127.0.0.1:9090
- Grafana UI: http://127.0.0.1:3000

## 7. Terraform Workflow
```bash
cd terraform
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform plan
```

## 8. Common Failures and Fixes
- Failed lint/test stage: fix code quality issues and push again.
- Image push failed: verify Docker credentials in Jenkins.
- Deployment rollout timeout: inspect pod events and logs.
- No metrics in Prometheus: verify `/metrics` endpoint and service DNS.
- Terraform backend error: verify S3 bucket and DynamoDB table names.
