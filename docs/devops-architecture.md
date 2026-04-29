# DevOps Architecture and Design Notes

## Problem Statement
The baseline Django API is functionally complete but operationally weak without automated quality gates, repeatable deployments, scalable runtime orchestration, and observability.

## Objective Mapping
- Containerization: multi-stage Docker build in `docker/Dockerfile`
- CI/CD: declarative pipeline in `Jenkinsfile`
- Orchestration: Kubernetes manifests in `k8s/`
- IaC: Terraform stack in `terraform/`
- Monitoring: Prometheus + Grafana manifests in `k8s/monitoring/`

## DFD Level 0 (Context)
```mermaid
flowchart LR
    Dev[Developer] -->|git push / PR merge| Pipeline[DevOps Pipeline System]
    Ops[Operations Team] -->|config + approvals| Pipeline
    Pipeline -->|deploy artifacts| K8s[Kubernetes Cluster]
    Pipeline -->|metrics and alerts| MonUsers[Monitoring Users]
    K8s -->|runtime metrics| Pipeline
```

## DFD Level 1 (Expanded)
```mermaid
flowchart LR
    P1[P1 Source Control and Webhook] --> P2[P2 CI Pipeline Jenkins]
    P2 --> P3[P3 Container Build and Registry]
    P2 --> P4[P4 Infrastructure Provisioning Terraform]
    P3 --> D1[(D1 Image Registry)]
    D1 --> P5[P5 Orchestration Kubernetes]
    P4 --> P5
    P5 --> K8s[Kubernetes Cluster]
    K8s --> P6[P6 Monitoring Prometheus]
    P6 --> D3[(D3 Time-Series Store)]
    D3 --> P7[P7 Dashboard and Alerting Grafana and Alerting Rules]
    P7 --> Ops
```

## CI/CD Flowchart
```mermaid
flowchart TD
    A([Start: Git Push]) --> B[Checkout]
    B --> C[Install Dependencies]
    C --> D{Lint Pass?}
    D -- No --> X[Notify Developer and Stop]
    D -- Yes --> E{Tests Pass?}
    E -- No --> X
    E -- Yes --> F[Build Docker Image]
    F --> G[Push Image]
    G --> H[Terraform Plan/Apply]
    H --> I[Kubernetes Rolling Deploy]
    I --> J{Readiness Healthy?}
    J -- No --> X
    J -- Yes --> K[Prometheus Scrape]
    K --> L[Grafana Dashboard and Alerts]
    L --> M([End: Deployment Live])
```

## Kubernetes Runtime Standards
- Deployment runs with 3 replicas.
- Rolling update strategy sets `maxUnavailable: 0` and `maxSurge: 1`.
- Liveness, readiness, and startup probes are enabled.
- HPA scales between 2 and 10 replicas based on CPU.
- ConfigMap and Secret are used for app configuration.

## Observability Standards
- Prometheus scrape interval: 15s.
- App metrics endpoint: `/metrics`.
- Baseline alerts include high P95 latency and high 5xx ratio.
- Grafana dashboard provisions API request rate and error trends.
