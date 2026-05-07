# SlugTerraAPI - AWS Free Tier Deployment Guide

**⚠️ IMPORTANT**: This guide is optimized for AWS **Free Tier only**. It uses EC2 + Docker instead of EKS to minimize costs.

- **12-month free tier**: After 12 months, resources will incur charges
- **750 hours/month limit**: Equivalent to ~31 days of continuous running
- **Recommended region**: `us-east-1` (best free tier coverage)
- **Monthly cost after 12 months**: ~$69/month

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [AWS Credentials Setup](#aws-credentials-setup)
3. [Infrastructure Provisioning with Terraform](#infrastructure-provisioning-with-terraform)
4. [Verify Deployment](#verify-deployment)
5. [Deploy Application](#deploy-application)
6. [Access the Application](#access-the-application)
7. [Monitoring](#monitoring)
8. [Scaling](#scaling)
9. [Free Tier Monitoring](#free-tier-monitoring)
10. [Cleanup and Teardown](#cleanup-and-teardown)
11. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- **AWS CLI v2**: [Download and install](https://aws.amazon.com/cli/)
  ```bash
  aws --version  # Verify installation (v2.x.x or higher)
  ```

- **Terraform**: [Download and install](https://www.terraform.io/downloads)
  ```bash
  terraform version  # Verify installation (v1.6 or higher)
  ```

- **Docker**: [Download and install](https://docs.docker.com/get-docker/)
  ```bash
  docker --version  # Verify installation
  ```

- **SSH Client**: For connecting to EC2 instances

### AWS Account Requirements

- Active AWS account (free tier eligible)
- IAM user with permissions for:
  - EC2 (VPC, Security Groups, Instances, Key Pairs)
  - RDS (Database provisioning)
  - ElasticLoadBalancing (Application Load Balancer)
  - CloudWatch (logs and monitoring)
  - S3 (for Terraform state)
  - IAM (instance profiles)

---

## AWS Credentials Setup

### Step 1: Create AWS Access Keys

1. Log in to the [AWS Management Console](https://console.aws.amazon.com/)
2. Navigate to **IAM** → **Users** → Select your user
3. Click **Create access key** under the **Access keys** section
4. Save your **Access Key ID** and **Secret Access Key** securely

### Step 2: Configure AWS CLI

```bash
aws configure
```

When prompted, enter:
- **AWS Access Key ID**: `<your-access-key>`
- **AWS Secret Access Key**: `<your-secret-key>`
- **Default region**: `us-east-1` (recommended for free tier)
- **Default output format**: `json`

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

### Terraform Resources Created

**Free Tier Eligible (750 hrs/month for 12 months):**
- 2× EC2 t2.micro instances
- RDS PostgreSQL db.t2.micro (20GB storage)
- Application Load Balancer (ALB)
- VPC with public subnets
- Security Groups
- S3 bucket for Terraform state
- DynamoDB table for state locking

**NOT Used (Not Free Tier):**
- ❌ EKS (Kubernetes) - $0.10/hour
- ❌ NAT Gateway - $0.45/hour + data charges
- ❌ ECR (private container registry)

### Step 1: Navigate to Terraform Directory

```bash
cd config/terraform
```

### Step 2: Review Configuration

```bash
cat terraform.tfvars
cat main.tf
```

### Step 3: Update terraform.tfvars (if needed)

Edit `terraform.tfvars`:

```hcl
aws_region        = "us-east-1"              # Best free tier coverage
project_name      = "slugapi"
environment       = "dev"
vpc_cidr           = "10.20.0.0/16"
postgres_password = "ChangeMe!SecurePass123" # CHANGE THIS!
```

**⚠️ CRITICAL: Use a strong database password!**

### Step 4: Initialize Terraform

```bash
terraform init
```

### Step 5: Validate Configuration

```bash
terraform validate
```

### Step 6: Preview Resources

```bash
terraform plan
```

Review output - should show:
- 2 EC2 t2.micro instances
- 1 RDS db.t2.micro
- 1 Application Load Balancer
- 1 VPC with public subnets
- Security Groups

### Step 7: Apply Configuration

```bash
terraform apply -auto-approve
```

⏱️ **Expected time**: 10-15 minutes

Monitor output for:
```
aws_instance.app[0]: Creating...
aws_instance.app[1]: Creating...
aws_db_instance.postgres: Creating...
aws_lb.app: Creating...
...
Apply complete! Resources: 15 added
```

### Step 8: Save Outputs

```bash
terraform output
```

Save these values (you'll need them):
```
load_balancer_dns = "slugapi-dev-alb-XXXX.us-east-1.elb.amazonaws.com"
ec2_instance_ips = [
  "XX.XX.XX.XX",
  "YY.YY.YY.YY"
]
postgres_endpoint = "slugapi-dev-postgres.XXXXX.rds.amazonaws.com"
postgres_port = 5432
```

---

## Verify Deployment

### Step 1: SSH into an EC2 Instance

Get an instance IP from the outputs above:

```bash
ssh -i ~/.ssh/slugapi-dev.pem ubuntu@<instance-ip>
```

To create an SSH key pair:
```bash
aws ec2 create-key-pair --key-name slugapi-dev --region us-east-1 --query 'KeyMaterial' --output text > ~/.ssh/slugapi-dev.pem
chmod 400 ~/.ssh/slugapi-dev.pem
```

### Step 2: Check Docker Installation

```bash
sudo docker --version
sudo docker-compose --version
```

### Step 3: Verify Database Connectivity

```bash
sudo apt-get install postgresql-client -y
psql -h <postgres_endpoint> -U postgres -d slugdb -c "SELECT version();"
```

When prompted for password, enter your `postgres_password`

---

## Deploy Application

### Option 1: Using Docker (Recommended)

On one of the EC2 instances:

```bash
# Create app directory
sudo mkdir -p /opt/slugapi
cd /opt/slugapi

# Clone your repository (adjust URL)
sudo git clone https://github.com/yourusername/SlugTerraAPI.git .

# Create .env file
sudo tee .env > /dev/null << EOF
DB_HOST=<postgres_endpoint>
DB_PORT=5432
DB_NAME=slugdb
DB_USER=postgres
DB_PASSWORD=<your-postgres-password>
DEBUG=False
ALLOWED_HOSTS=<load_balancer_dns>
EOF

# Build and run with docker-compose
sudo docker-compose up -d
```

### Option 2: Manual Setup

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Python
sudo apt-get install -y python3.12 python3-pip python3-venv postgresql-client

# Setup application
cd /opt/slugapi
git clone https://github.com/yourusername/SlugTerraAPI.git .

# Create virtual environment
python3.12 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export DB_HOST=<postgres_endpoint>
export DB_USER=postgres
export DB_PASSWORD=<your-postgres-password>
export DB_NAME=slugdb

# Run migrations
python manage.py migrate

# Collect static files
python manage.py collectstatic --noinput

# Start with gunicorn
gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 2 &
```

---

## Access the Application

### Via Load Balancer (Recommended)

```
http://<load_balancer_dns>
```

Example: `http://slugapi-dev-alb-123456.us-east-1.elb.amazonaws.com`

### Direct to EC2 (Testing)

```
http://<instance-ip>:8000
```

---

## Monitoring

### CloudWatch Logs

View instance logs:
```bash
aws ec2 describe-instance-status --instance-ids <instance-id> --region us-east-1
```

### EC2 Health

```bash
aws ec2 describe-instances --instance-ids <instance-id> --region us-east-1
```

### ALB Health

```bash
aws elbv2 describe-target-health --target-group-arn <target-group-arn> --region us-east-1
```

### RDS Monitoring

```bash
aws rds describe-db-instances --db-instance-identifier slugapi-dev-postgres --region us-east-1
```

---

## Scaling

### Add More EC2 Instances

Edit `config/terraform/main.tf`:

```hcl
resource "aws_instance" "app" {
  count = 3  # Increase from 2 to 3
  ...
}
```

Apply changes:
```bash
terraform apply -auto-approve
```

---

## Free Tier Monitoring

### Check Current Usage

```bash
# Open AWS Console:
# Billing → Billing Dashboard → Free Tier Dashboard
```

### Cost Breakdown (12 Months Free Tier)

| Resource | Monthly Cost | Free Tier | Duration |
|----------|---------|-----------|----------|
| 2× t2.micro EC2 | $15.36 | 1,500 hrs | 12 mo |
| db.t2.micro RDS | $31.36 | 750 hrs + 20GB | 12 mo |
| ALB | $22.50 | Included | 12 mo |
| VPC/SG | $0 | FREE | - |
| **Total** | **$69.22** | **FREE** | **12 mo** |

**After 12 months**: ~$69/month for continued operation

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
---

## Cleanup and Teardown

⚠️ **IMPORTANT**: Destroy resources when not in use to avoid charges after free tier ends.

### Destroy All Infrastructure

```bash
cd config/terraform
terraform destroy -auto-approve
```

This will terminate:
- 2 EC2 instances
- RDS database
- Application Load Balancer
- VPC and subnets
- Security groups

---

## Troubleshooting

### Issue: EC2 instances stuck in "initializing"

Check user data logs:
```bash
ssh -i ~/.ssh/slugapi-dev.pem ubuntu@<instance-ip>
tail -f /var/log/user_data.log
```

### Issue: Cannot connect to RDS from EC2

1. Verify security group allows port 5432:
```bash
aws ec2 describe-security-groups --group-ids <rds-sg-id> --region us-east-1
```

2. Test connectivity:
```bash
ssh -i ~/.ssh/slugapi-dev.pem ubuntu@<instance-ip>
sudo apt-get install postgresql-client -y
psql -h <postgres_endpoint> -U postgres -c "SELECT 1;"
```

### Issue: ALB not routing traffic

1. Check target group health:
```bash
aws elbv2 describe-target-health --target-group-arn <target-group-arn> --region us-east-1
```

2. Verify security group allows port 8000:
```bash
aws ec2 describe-security-groups --group-ids <ec2-sg-id> --region us-east-1
```

### Issue: Application error after deployment

SSH to instance and check logs:
```bash
ssh -i ~/.ssh/slugapi-dev.pem ubuntu@<instance-ip>
docker logs -f <container-name>
# or
tail -f /opt/slugapi/app.log
```

### Issue: Out of free tier hours

Monitor usage:
```bash
aws ec2 describe-account-attributes --attribute-names supported-platforms --region us-east-1
```

---

## References

- [AWS Free Tier](https://aws.amazon.com/free/)
- [Free Tier FAQ](https://aws.amazon.com/free/free-tier-faq/)
- [EC2 Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [RDS Pricing](https://aws.amazon.com/rds/pricing/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Django Deployment](https://docs.djangoproject.com/en/stable/howto/deployment/)

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

**Cause**: No Kubernetes cluster configured or kubeconfig not present.

**Note**: This repository no longer provisions EKS clusters as part of the default free-tier workflow. If you still need to use an existing EKS cluster, follow the official AWS EKS documentation to update kubeconfig manually.

**If you're using EC2/docker deployment**: verify the app on EC2 directly (SSH + Docker logs) or use the load balancer DNS in your browser.

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

