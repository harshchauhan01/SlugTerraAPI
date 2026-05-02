# SlugTerraAPI - AWS Deployment Guide

This guide provides detailed step-by-step instructions for deploying SlugTerraAPI on AWS using Terraform, ECR, and EKS.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [AWS Credentials Setup](#aws-credentials-setup)
3. [Infrastructure Provisioning with Terraform](#infrastructure-provisioning-with-terraform)
4. [Build and Push Docker Image to ECR](#build-and-push-docker-image-to-ecr)
5. [Deploy to EKS](#deploy-to-eks)
6. [Configure Kubernetes Resources](#configure-kubernetes-resources)
7. [Verify Deployment](#verify-deployment)
8. [Access the Application](#access-the-application)
9. [Monitoring and Alerting](#monitoring-and-alerting)
10. [Scaling and Auto-Recovery](#scaling-and-auto-recovery)
11. [Cost Optimization](#cost-optimization)
12. [Cleanup and Teardown](#cleanup-and-teardown)
13. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before you begin, ensure you have the following tools installed on your local machine:

### Required Software

- **AWS CLI v2**: [Download and install](https://aws.amazon.com/cli/)
  ```bash
  aws --version  # Verify installation (v2.x.x or higher)
  ```

- **kubectl**: [Download and install](https://kubernetes.io/docs/tasks/tools/)
  ```bash
  kubectl version --client  # Verify installation
  ```

- **Terraform**: [Download and install](https://www.terraform.io/downloads)
  ```bash
  terraform version  # Verify installation (v1.0 or higher)
  ```

- **Docker**: [Download and install](https://docs.docker.com/get-docker/)
  ```bash
  docker --version  # Verify installation
  ```

- **helm** (optional, for advanced deployments): [Download and install](https://helm.sh/docs/intro/install/)

### AWS Account Requirements

- Active AWS account with appropriate permissions
- IAM user or role with the following permissions:
  - EC2 (VPC, Security Groups, Instances)
  - ECS/EKS (Cluster creation and management)
  - RDS (Database provisioning)
  - ECR (Container registry)
  - IAM (Role creation)
  - CloudFormation (for stack management)
  - S3 (for Terraform state)
  - CloudWatch (for monitoring)

---

## AWS Credentials Setup

### Step 1: Create AWS Access Keys

1. Log in to the [AWS Management Console](https://console.aws.amazon.com/)
2. Navigate to **IAM** → **Users** → Select your user
3. Click **Create access key** under the **Access keys** section
4. Save your **Access Key ID** and **Secret Access Key** securely

### Step 2: Configure AWS CLI

#### Option A: Interactive Configuration

```bash
aws configure
```

When prompted, enter:
- AWS Access Key ID: `<your-access-key>`
- AWS Secret Access Key: `<your-secret-key>`
- Default region: `ap-south-1` (or your preferred region)
- Default output format: `json`

#### Option B: Environment Variables (Windows PowerShell)

```powershell
$env:AWS_ACCESS_KEY_ID = "<your-access-key>"
$env:AWS_SECRET_ACCESS_KEY = "<your-secret-key>"
$env:AWS_REGION = "ap-south-1"
```

#### Option C: Environment Variables (Linux/macOS)

```bash
export AWS_ACCESS_KEY_ID="<your-access-key>"
export AWS_SECRET_ACCESS_KEY="<your-secret-key>"
export AWS_REGION="ap-south-1"
```

### Step 3: Verify AWS Credentials

```bash
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAI...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-user"
}
```

---

## Infrastructure Provisioning with Terraform

Terraform will provision the following AWS resources:
- VPC with public and private subnets
- EKS cluster
- RDS PostgreSQL instance
- ECR repository for Docker images
- S3 bucket for remote state
- DynamoDB table for state locking

### Step 1: Prepare Terraform Configuration

Navigate to the Terraform directory:

```bash
cd config/terraform
```

### Step 2: Copy Configuration Templates

```bash
# Create backend configuration (for remote state)
cp backend.tf.example backend.tf

# Create variables configuration
cp terraform.tfvars.example terraform.tfvars
```

### Step 3: Update terraform.tfvars

Edit `terraform.tfvars` and update the following variables:

```hcl
# AWS Region
aws_region = "ap-south-1"

# Project identifier (used for resource naming)
project_name = "slugapi"

# Environment
environment = "production"

# Database configuration
db_engine_version = "16.1"
db_instance_class = "db.t3.micro"  # For production, consider db.t3.small or larger
db_username = "slugadmin"
db_password = "YourStrongPassword123!"  # Change this to a strong password

# EKS configuration
eks_node_count = 2  # Number of worker nodes
eks_node_type = "t3.medium"  # Instance type for worker nodes

# Container registry
ecr_repository_name = "slugapi"

# VPC configuration
vpc_cidr = "10.0.0.0/16"
```

**Important Security Notes:**
- Use a strong database password (min 8 characters, mixed case, numbers, special chars)
- Never commit `terraform.tfvars` to version control (add to `.gitignore`)
- Store passwords in AWS Secrets Manager after deployment
- Enable encryption at rest for databases and volumes

### Step 4: Initialize Terraform

```bash
terraform init
```

This command will:
- Download required Terraform providers
- Configure the remote state backend
- Initialize the working directory

### Step 5: Validate Configuration

```bash
terraform validate
```

Expected output: `Success! The configuration is valid.`

### Step 6: Review Terraform Plan

```bash
terraform plan -out=tfplan
```

This will display all resources that Terraform will create. Review the output carefully.

### Step 7: Apply Terraform Configuration

```bash
terraform apply tfplan
```

**This will provision AWS resources. It may take 15-20 minutes.**

Wait for the process to complete. Terraform will output important values:

```
Outputs:

eks_cluster_name = "slugapi-eks"
eks_cluster_endpoint = "https://XXXXXX.eks.amazonaws.com"
ecr_repository_url = "XXXXXXXXX.dkr.ecr.ap-south-1.amazonaws.com/slugapi"
rds_endpoint = "slugapi-db.XXXXX.rds.amazonaws.com"
```

**Save these outputs for the next steps.**

### Step 8: Update kubeconfig

Configure kubectl to access the newly created EKS cluster:

```bash
aws eks update-kubeconfig --region ap-south-1 --name slugapi-eks
```

Verify kubectl connectivity:

```bash
kubectl get nodes
```

Expected output: List of worker nodes with status `Ready`

---

## Build and Push Docker Image to ECR

### Step 1: Retrieve ECR Repository URL

From Terraform outputs, get your ECR repository URL (format: `XXXXXXXXX.dkr.ecr.ap-south-1.amazonaws.com/slugapi`)

### Step 2: Login to ECR

```bash
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <ECR_REPOSITORY_URL>
```

Expected output: `Login Succeeded`

### Step 3: Build Docker Image

Navigate to the config directory:

```bash
cd ../..  # or navigate to config/
```

Build the image:

```bash
docker build -f docker/Dockerfile -t slugapi:latest .
```

### Step 4: Tag Image for ECR

```bash
docker tag slugapi:latest <ECR_REPOSITORY_URL>:latest
```

Example:
```bash
docker tag slugapi:latest 123456789012.dkr.ecr.ap-south-1.amazonaws.com/slugapi:latest
```

### Step 5: Push Image to ECR

```bash
docker push <ECR_REPOSITORY_URL>:latest
```

Verify the image was pushed:

```bash
aws ecr describe-images --repository-name slugapi --region ap-south-1
```

---

## Deploy to EKS

### Step 1: Update Kubernetes Manifests

Edit `k8s/deployment.yml` and update the image reference:

```yaml
spec:
  containers:
  - name: slugapi
    image: <ECR_REPOSITORY_URL>:latest  # Replace with your ECR URL
```

### Step 2: Create Kubernetes Namespace

```bash
kubectl apply -f k8s/namespace.yml
```

Verify:
```bash
kubectl get namespace slugapi-ns
```

### Step 3: Create Secrets and ConfigMaps

Update `k8s/secret.yml` with sensitive data:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: slugapi-secret
  namespace: slugapi-ns
type: Opaque
stringData:
  DJANGO_SECRET_KEY: "your-django-secret-key"
  POSTGRES_PASSWORD: "your-postgres-password"
  DEBUG: "False"
```

Apply secrets and configmaps:

```bash
kubectl apply -f k8s/secret.yml
kubectl apply -f k8s/configmap.yml
```

### Step 4: Deploy PostgreSQL

```bash
kubectl apply -f k8s/postgres.yml
```

Wait for PostgreSQL to be ready:

```bash
kubectl get pods -n slugapi-ns -w
```

### Step 5: Deploy Redis

```bash
kubectl apply -f k8s/redis.yml
```

### Step 6: Deploy SlugTerraAPI Application

```bash
kubectl apply -f k8s/deployment.yml
```

### Step 7: Create Service

```bash
kubectl apply -f k8s/service.yml
```

### Step 8: Setup Ingress

For EKS, you need to install the NGINX Ingress Controller first:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.0/deploy/static/provider/aws/deploy.yaml
```

Wait for the ingress controller to be ready:

```bash
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
```

Then apply your ingress manifest:

```bash
kubectl apply -f k8s/ingress.yml
```

### Step 9: Setup Auto-Scaling

```bash
kubectl apply -f k8s/hpa.yml
```

---

## Configure Kubernetes Resources

### Step 1: Verify All Pods are Running

```bash
kubectl get pods -n slugapi-ns
```

Expected output: All pods should have status `Running`

### Step 2: Run Database Migrations

```bash
kubectl exec -it deployment/slugapi -n slugapi-ns -- python manage.py migrate
```

### Step 3: Create Superuser (Optional)

```bash
kubectl exec -it deployment/slugapi -n slugapi-ns -- python manage.py createsuperuser
```

### Step 4: Check Logs

```bash
kubectl logs -f deployment/slugapi -n slugapi-ns
```

---

## Verify Deployment

### Step 1: Check Service Status

```bash
kubectl get svc -n slugapi-ns
```

Record the `EXTERNAL-IP` or `LOAD-BALANCER-INGRESS` from the service output.

### Step 2: Get Ingress Address

```bash
kubectl get ingress -n slugapi-ns
```

Record the address from the ingress output.

### Step 3: Verify Pod Health

```bash
kubectl get pods -n slugapi-ns -o wide
```

### Step 4: Check Resource Usage

```bash
kubectl top nodes
kubectl top pods -n slugapi-ns
```

---

## Access the Application

### Step 1: Get Load Balancer URL

```bash
kubectl get ingress -n slugapi-ns --output wide
```

The `ADDRESS` column contains your application URL.

### Step 2: Access API Endpoints

Replace `<LOAD_BALANCER_URL>` with the URL from above:

- **Home**: http://\<LOAD_BALANCER_URL\>/
- **API Documentation (Swagger)**: http://\<LOAD_BALANCER_URL\>/swagger/
- **API Documentation (ReDoc)**: http://\<LOAD_BALANCER_URL\>/redoc/
- **List Slugs**: http://\<LOAD_BALANCER_URL\>/api/slugs/
- **Admin Panel**: http://\<LOAD_BALANCER_URL\>/admin/

### Step 3: Test API Connectivity

```bash
curl http://<LOAD_BALANCER_URL>/
```

Expected: JSON response with API information

---

## Monitoring and Alerting

### Step 1: Deploy Monitoring Stack

Apply Prometheus and Grafana:

```bash
kubectl apply -f k8s/monitoring/namespace.yml
kubectl apply -f k8s/monitoring/
```

### Step 2: Deploy Monitoring Operator (Optional)

If using kube-prometheus-stack:

```bash
kubectl apply -f k8s/monitoring-operator/
```

### Step 3: Access Prometheus

Port-forward Prometheus:

```bash
kubectl port-forward -n monitoring service/prometheus 9090:9090
```

Open: http://127.0.0.1:9090

### Step 4: Access Grafana

Port-forward Grafana:

```bash
kubectl port-forward -n monitoring service/grafana 3000:3000
```

Open: http://127.0.0.1:3000

Default credentials:
- Username: `admin`
- Password: `admin` (change after first login)

### Step 5: View Application Metrics

In Grafana, create a new dashboard and add queries to visualize:
- Request rate (from `/metrics`)
- Error rate (5xx responses)
- Response time (p95, p99)
- Pod CPU and memory usage

---

## Scaling and Auto-Recovery

### Step 1: Horizontal Pod Autoscaler (HPA)

Check HPA configuration:

```bash
kubectl get hpa -n slugapi-ns
```

The HPA is configured to scale pods between 2-10 replicas based on CPU usage.

### Step 2: Manual Pod Scaling

To manually scale pods:

```bash
kubectl scale deployment/slugapi --replicas=3 -n slugapi-ns
```

### Step 3: Monitor Autoscaling

```bash
kubectl get hpa -n slugapi-ns --watch
```

### Step 4: Configure Pod Disruption Budget

The deployment already includes liveness and readiness probes that will automatically restart unhealthy pods.

---

## Cost Optimization

This section provides strategies and commands to minimize AWS costs while running SlugTerraAPI.

### AWS Free Tier Eligibility

Check if your deployment qualifies for AWS Free Tier benefits:

**Free Tier Services (12 months):**
- **EC2**: 750 hours/month of `t2.micro` or `t3.micro`
- **RDS**: 750 hours/month of `db.t2.micro` or `db.t3.micro` (single AZ only)
- **NAT Gateway**: Not included in free tier
- **Data Transfer**: 100 GB/month outbound (first year)

**Always Free Services:**
- **ECR**: 500 MB storage
- **CloudWatch**: 10 custom metrics
- **CloudTrail**: 1 trail (read-only events)

### Minimal-Cost Configuration for Testing

For development and testing, use this cost-optimized `terraform.tfvars`:

```hcl
# Minimal-cost configuration
aws_region = "us-free-tier-eligible-region"  # Use us-east-1 for best free tier coverage

# Database - Smallest free tier eligible instance
db_instance_class = "db.t3.micro"
db_engine_version = "16.1"
db_username = "slugadmin"
db_password = "YourStrongPassword123!"

# EKS - Minimal nodes
eks_node_count = 1                    # Single node (minimum)
eks_node_type = "t3.micro"           # Burstable, lowest cost

# ECR
ecr_repository_name = "slugapi"

# VPC - Single AZ only
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a"]  # Use single AZ to avoid NAT gateway charges
```

**Estimated Monthly Cost (Minimal Configuration):**
- EKS Cluster: $73.00
- 1x t3.micro EC2 node: $7.50
- RDS db.t3.micro: $15.00
- ECR storage (first 500 MB): Free
- Data transfer: ~$1-5 (depends on traffic)
- **Total**: ~$96-101/month (subject to free tier eligibility)

### Recommended Production Configuration

For production with modest traffic, use this configuration:

```hcl
aws_region = "ap-south-1"  # Lower pricing in some regions

db_instance_class = "db.t3.small"    # Minimum recommended for production
eks_node_count = 2
eks_node_type = "t3.small"

vpc_cidr = "10.0.0.0/16"
```

**Estimated Monthly Cost (Production Configuration):**
- EKS Cluster: $73.00
- 2x t3.small EC2 nodes: $30.00 ($15 each)
- RDS db.t3.small: $30.00
- Data transfer: ~$5-20
- Monitoring (CloudWatch): ~$10-15
- **Total**: ~$150-190/month

### Cost Monitoring Commands

#### Step 1: Enable AWS Cost Alerts

Set up billing alerts:

```bash
# Create SNS topic for cost alerts
aws sns create-topic --name slugapi-cost-alerts --region us-east-1

# Note the TopicArn from output
# Then manually configure billing alerts in AWS Console:
# Billing → Preferences → Alert Preferences
```

#### Step 2: Check Current Spending

```bash
# View current month's cost estimate
aws ce get-cost-and-usage \
  --time-period Start=2026-05-01,End=2026-05-02 \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE \
  --region us-east-1
```

#### Step 3: Estimate Monthly Costs by Service

```bash
# Cost breakdown by AWS service
aws ce get-cost-and-usage \
  --time-period Start=2026-04-01,End=2026-05-01 \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE \
  --region us-east-1 \
  --query 'ResultsByTime[0].Groups' \
  --output table
```

#### Step 4: View Cost by Resource Tags

Tag all resources and track costs:

```bash
# List all resources and their costs
aws ce get-cost-and-usage \
  --time-period Start=2026-04-01,End=2026-05-01 \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=TAG,Key=Environment \
  --region us-east-1
```

### Cost-Saving Strategies

#### 1. Scale Down When Not in Use

Reduce replicas during off-hours:

```bash
# Scale down to 1 replica for development
kubectl scale deployment/slugapi --replicas=1 -n slugapi-ns

# Scale down PostgreSQL (not recommended for production)
kubectl scale deployment/postgres --replicas=0 -n slugapi-ns

# Or delete entire cluster for extended downtime
terraform destroy
```

#### 2. Use Reserved Instances (RI)

Reserve capacity for 1-year or 3-year terms (30-70% discount):

```bash
# Command-line reservation purchase not supported; use AWS Console:
# EC2 → Reserved Instances → Purchase Reserved Instances
# Select: t3.micro, 1-year, All Upfront (best discount)
```

#### 3. Use Spot Instances for Non-Critical Workloads

Save up to 90% on EC2 costs:

```hcl
# Update Terraform configuration to use Spot instances
# In your Terraform worker node configuration:

spot_price = "0.03"  # Max price you'll pay
instance_interruption_behavior = "terminate"

# Note: Not suitable for production critical services
```

#### 4. Right-Size Your Resources

Current configuration analysis:

```bash
# Check actual CPU and memory usage
kubectl top nodes
kubectl top pods -n slugapi-ns

# If mostly idle, downsize instances:
# t3.small → t3.micro (50% cost reduction)
# db.t3.small → db.t3.micro (50% cost reduction)
```

#### 5. Delete Unused Resources

```bash
# List unattached EBS volumes
aws ec2 describe-volumes --filters Name=status,Values=available --region ap-south-1

# Delete unattached volumes
aws ec2 delete-volume --volume-id vol-XXXXX --region ap-south-1

# List unused Elastic IPs
aws ec2 describe-addresses --filters Name=association-id,Values= --region ap-south-1

# Release unused Elastic IP
aws ec2 release-address --allocation-id eipalloc-XXXXX --region ap-south-1
```

#### 6. Use Data Transfer Optimization

Minimize egress charges (most expensive):

```bash
# Monitor data transfer costs
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name NetworkOut \
  --start-time 2026-04-01T00:00:00Z \
  --end-time 2026-05-01T00:00:00Z \
  --period 86400 \
  --statistics Sum \
  --region ap-south-1

# Recommendations:
# - Use CloudFront for image delivery
# - Keep database in same AZ as compute
# - Use S3 Gateway Endpoint to avoid NAT Gateway charges
```

#### 7. Enable S3 Lifecycle Policies

Auto-delete old logs and backups:

```bash
# Create lifecycle policy for S3 buckets storing logs
aws s3api put-bucket-lifecycle-configuration \
  --bucket slugapi-logs \
  --lifecycle-configuration '{
    "Rules": [
      {
        "ID": "DeleteOldLogs",
        "Status": "Enabled",
        "Prefix": "logs/",
        "Expiration": {"Days": 30}
      }
    ]
  }' \
  --region ap-south-1
```

#### 8. Use RDS Automatic Backups Retention

Limit backup storage costs:

```bash
# Reduce backup retention to 7 days (from 30)
aws rds modify-db-instance \
  --db-instance-identifier slugapi-db \
  --backup-retention-period 7 \
  --apply-immediately \
  --region ap-south-1
```

### Alternative Cost-Saving Deployment Options

#### Option 1: Use ECS Fargate Instead of EKS

**Pros:**
- No EC2 instance management
- Pay only for compute capacity used
- Better for variable traffic

**Cons:**
- Less flexible than Kubernetes
- Cold start latency

**Estimated Cost:** $50-80/month (vs $150-190 with EKS)

#### Option 2: Use Aurora Serverless Instead of RDS

**Pros:**
- Auto-scales based on demand
- Pay per invocation
- Better for variable workloads

**Cons:**
- Not available in all regions
- Higher per-request cost at scale

**Estimated Cost:** $20-40/month (for low-traffic apps)

#### Option 3: Use Lightsail for Simple Deployments

**Pros:**
- Simpler management
- Fixed monthly price ($5-40/month)
- Better for small projects

**Cons:**
- Limited scalability
- Less control
- Not suitable for high-traffic apps

**Estimated Cost:** $20-40/month

### Cost Optimization Checklist

- [ ] Use free tier eligible instance types (`t3.micro`, `db.t3.micro`)
- [ ] Set up CloudWatch billing alarms
- [ ] Enable AWS Cost Explorer for monitoring
- [ ] Review monthly costs and identify spikes
- [ ] Delete unused resources (volumes, IPs, snapshots)
- [ ] Consolidate workloads to fewer AZs
- [ ] Use VPC endpoints to avoid NAT Gateway charges
- [ ] Consider reserved instances for long-running workloads
- [ ] Implement auto-scaling policies
- [ ] Right-size instances based on actual usage
- [ ] Use spot instances for non-critical workloads
- [ ] Enable S3 lifecycle policies for log retention
- [ ] Monitor and limit data transfer costs
- [ ] Review database backup retention policies

### Cost-Saving Commands Summary

```bash
# Quick commands to reduce costs immediately:

# 1. Scale down to single pod
kubectl scale deployment/slugapi --replicas=1 -n slugapi-ns

# 2. Check current costs
aws ce get-cost-and-usage \
  --time-period Start=2026-05-01,End=2026-05-02 \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE

# 3. List resources consuming costs
aws ec2 describe-instances --filters Name=instance-state-name,Values=running

# 4. Stop non-essential services
kubectl scale deployment/redis --replicas=0 -n slugapi-ns

# 5. Check resource utilization
kubectl top nodes
kubectl top pods -n slugapi-ns

# 6. View data transfer costs
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name NetworkOut \
  --start-time 2026-04-01T00:00:00Z \
  --end-time 2026-05-01T00:00:00Z \
  --period 86400 \
  --statistics Sum
```

---

## Cleanup and Teardown

### Step 1: Delete Kubernetes Resources (Keep Infrastructure)

```bash
kubectl delete -f k8s/monitoring-operator/  # If deployed
kubectl delete -f k8s/monitoring/           # If deployed
kubectl delete -f k8s/ingress.yml
kubectl delete -f k8s/hpa.yml
kubectl delete -f k8s/service.yml
kubectl delete -f k8s/deployment.yml
kubectl delete -f k8s/configmap.yml
kubectl delete -f k8s/secret.yml
kubectl delete -f k8s/redis.yml
kubectl delete -f k8s/postgres.yml
kubectl delete -f k8s/namespace.yml
```

### Step 2: Destroy AWS Infrastructure with Terraform

Navigate to Terraform directory:

```bash
cd config/terraform
```

View resources to be destroyed:

```bash
terraform plan -destroy
```

Destroy all infrastructure:

```bash
terraform destroy
```

Confirm by typing `yes` when prompted.

### Step 3: Delete ECR Repository (Optional)

```bash
aws ecr delete-repository --repository-name slugapi --force --region ap-south-1
```

### Step 4: Remove Local AWS Configuration (Optional)

```bash
aws configure --profile default
```

---

## Troubleshooting

### Issue: Pods Stuck in Pending State

**Cause**: Insufficient node resources or node initialization delay

**Solution**:
```bash
kubectl describe pod <pod-name> -n slugapi-ns
kubectl get nodes
kubectl describe node <node-name>
```

### Issue: Database Connection Errors

**Cause**: PostgreSQL service not ready or connection string incorrect

**Solution**:
```bash
kubectl get pods -n slugapi-ns | grep postgres
kubectl logs deployment/postgres -n slugapi-ns
```

Update the database connection string in `k8s/secret.yml` and reapply.

### Issue: Image Pull Errors from ECR

**Cause**: ECR credentials not configured or image doesn't exist

**Solution**:
```bash
# Verify image exists in ECR
aws ecr describe-images --repository-name slugapi --region ap-south-1

# Re-login to ECR
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <ECR_REPOSITORY_URL>

# Recreate image pull secret
kubectl create secret docker-registry ecr-secret \
  --docker-server=<ECR_REPOSITORY_URL> \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region ap-south-1) \
  -n slugapi-ns
```

### Issue: High Latency or Timeout Errors

**Cause**: Insufficient resources, network issues, or database bottleneck

**Solution**:
1. Check pod resource usage: `kubectl top pods -n slugapi-ns`
2. Check node resources: `kubectl top nodes`
3. Scale up pods: `kubectl scale deployment/slugapi --replicas=5 -n slugapi-ns`
4. Check RDS performance: AWS Console → RDS → DB Instances

### Issue: Terraform State Lock

**Cause**: Previous Terraform operation did not complete successfully

**Solution**:
```bash
cd config/terraform

# View lock information
terraform force-unlock <LOCK_ID>

# Or check DynamoDB table
aws dynamodb scan --table-name slugapi-tf-locks --region ap-south-1
```

### Issue: kubectl Commands Fail with "Unable to Connect to Server"

**Cause**: kubeconfig not updated or cluster unreachable

**Solution**:
```bash
# Update kubeconfig
aws eks update-kubeconfig --region ap-south-1 --name slugapi-eks

# Verify connection
kubectl cluster-info
```

### Issue: Cannot Push Image to ECR

**Cause**: Docker not logged into ECR or repository doesn't exist

**Solution**:
```bash
# Verify ECR repository exists
aws ecr describe-repositories --repository-names slugapi --region ap-south-1

# Re-login to Docker
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <ECR_REPOSITORY_URL>

# Verify Docker login
cat ~/.docker/config.json  # Check for ECR entry
```

---

## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Django on Kubernetes](https://docs.djangoproject.com/en/stable/)
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)

---

## Support

For issues or questions regarding AWS deployment, refer to:
1. Terraform outputs and logs
2. AWS CloudWatch logs and events
3. Kubernetes event logs: `kubectl describe pod <pod-name> -n slugapi-ns`
4. Application logs: `kubectl logs deployment/slugapi -n slugapi-ns`

