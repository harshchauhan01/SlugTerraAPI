# SlugTerraAPI - AWS kubeadm Deployment Guide

This guide matches the current AWS setup in `config/terraform1`:

- 1 EC2 master node
- 2 EC2 worker nodes
- kubeadm bootstrap on Ubuntu
- containerd as the runtime
- Calico as the CNI
- application deployed from `config/k8s`
- application image pulled from Docker Hub

This setup does not use EKS, RDS, ALB, or ECR. The EC2 cluster is only responsible for running Kubernetes.

## What you need

- AWS CLI configured with credentials that can create EC2, IAM, SSM, and networking resources
- Terraform installed
- An SSH key pair that matches `var.key_name` in `config/terraform1/variables.tf`
- Outbound internet access from the EC2 nodes so they can reach Docker Hub and Kubernetes package sources
- A public Docker Hub image for the app, for example `harshchauhan01/slug-api:latest`
- `kubectl` access on the master node

## 1. Provision the cluster

From the repository root:

```bash
cd config/terraform1
terraform init
terraform apply
```

This creates the VPC, subnet, security group, IAM role, and these EC2 instances:

- `master`
- `worker1`
- `worker2`

The master bootstrap script initializes Kubernetes, installs Calico, generates the join command, and stores it in SSM at `/k8s/join-command`. The workers wait for that value and join automatically.

Useful outputs:

- `master_public_ip`
- `worker1_public_ip`
- `worker2_public_ip`

## 2. Verify the cluster

SSH into the master node:

```bash
ssh -i ~/.ssh/<your-key>.pem ubuntu@<master_public_ip>
```

Then verify the nodes:

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

You should see the master and both workers in a `Ready` state after bootstrap finishes.

If the cluster is still coming up, check the bootstrap logs on the EC2 instances:

```bash
tail -f /var/log/master-bootstrap.log
tail -f /var/log/worker-bootstrap.log
```

## 3. Prepare the application manifests

Your app is already defined in Kubernetes manifests under `config/k8s`:

- `namespace.yml`
- `configmap.yml`
- `secret.yml`
- `postgres.yml`
- `redis.yml`
- `deployment.yml`
- `service.yml`
- `ingress.yml`
- `hpa.yml`

Use:
```
scp -i your-key.pem -r k8s ubuntu@<MASTER_PUBLIC_IP>:~
```

The Deployment already points to the Docker Hub image in `config/k8s/deployment.yml`:

```yaml
harshchauhan01/slug-api:latest
```

Because that image is already public on Docker Hub, the cluster should be able to pull it directly as long as the nodes have outbound internet access.

If you want to use a private image later, add an `imagePullSecret` to the Deployment.

## 4. Install cluster dependencies if needed

### Ingress controller

Your app manifest includes an Ingress with `ingressClassName: nginx`, so the cluster needs an NGINX ingress controller before that Ingress will work.

If you do not already have one installed, apply the official ingress-nginx manifest on the cluster:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml
```

If you do not want ingress, you can skip it and use `kubectl port-forward` instead.

### Storage for Postgres

`config/k8s/postgres.yml` uses a PVC named `postgres-data`. On bare kubeadm clusters, that PVC will only bind if you have a default StorageClass or another dynamic provisioner installed.

If the Postgres pod stays Pending, install a storage provisioner or provide a StorageClass before applying the database manifest.

## 5. Deploy the application

From the master node, in a checkout of this repository, apply the manifests in this order:

```bash
kubectl apply -f config/k8s/namespace.yml
kubectl apply -f config/k8s/configmap.yml
kubectl apply -f config/k8s/secret.yml
kubectl apply -f config/k8s/postgres.yml
kubectl apply -f config/k8s/redis.yml
kubectl apply -f config/k8s/deployment.yml
kubectl apply -f config/k8s/service.yml
kubectl apply -f config/k8s/ingress.yml
kubectl apply -f config/k8s/hpa.yml
```

Then verify rollout status:

```bash
kubectl get deploy,svc,ingress,hpa -n slugapi-ns
kubectl get pods -n slugapi-ns -w
kubectl rollout status deployment/slugapp -n slugapi-ns
```

## 6. Access the app

### Via ingress

If ingress-nginx is installed and DNS or port-forwarding is configured for it, the app is exposed through the Ingress resource.

### Via port-forward

If you want a quick local test, port-forward the Service:

```bash
kubectl port-forward -n slugapi-ns service/slugapp 8000:80
```

Then open:

```bash
http://127.0.0.1:8000/
```

## 7. What happens inside the pod

The container entrypoint waits for Postgres, runs Django migrations, and then starts Gunicorn. That means the app pod will not fully start until the database service is reachable.

## 8. Common issues

### Image pull errors

If the Deployment cannot pull the image, confirm the Docker Hub repository is public and reachable from the EC2 nodes.

### Postgres PVC Pending

If the Postgres pod is Pending, check the PVC and StorageClass:

```bash
kubectl get pvc -n slugapi-ns
kubectl get storageclass
kubectl describe pvc postgres-data -n slugapi-ns
```

### Ingress not working

If the Ingress does not route traffic, confirm the ingress controller is installed and healthy:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### Pods not becoming Ready

Check events and logs:

```bash
kubectl describe pod <pod-name> -n slugapi-ns
kubectl logs <pod-name> -n slugapi-ns
```

## 9. Cleanup

When you are done, remove the Kubernetes resources first, then destroy the EC2 infrastructure:

```bash
kubectl delete -f config/k8s/hpa.yml
kubectl delete -f config/k8s/ingress.yml
kubectl delete -f config/k8s/service.yml
kubectl delete -f config/k8s/deployment.yml
kubectl delete -f config/k8s/redis.yml
kubectl delete -f config/k8s/postgres.yml
kubectl delete -f config/k8s/secret.yml
kubectl delete -f config/k8s/configmap.yml
kubectl delete -f config/k8s/namespace.yml
```

Then:

```bash
cd config/terraform1
terraform destroy
```

## Summary

The current deployment flow is:

1. Run `terraform apply` in `config/terraform1`
2. Wait for the master and workers to finish kubeadm bootstrap
3. SSH into the master
4. Install ingress or storage support if your cluster needs it
5. Apply the manifests in `config/k8s`
6. Access the app through ingress or port-forward
