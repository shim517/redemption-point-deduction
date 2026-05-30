# Redemption Point Deduction

Infrastructure-as-Code and Kubernetes manifests for **The Redemption** — a business-critical AWS EKS microservice handling global hotel loyalty-point deductions.

> Architecture diagram and design document (PDF) are included as separate files.

---

## Repository structure

```
.
├── terraform/
│   ├── shared/
│   │   ├── infra/          # VPC, subnets, NAT GWs, NACLs, VPC endpoints, flow logs
│   │   ├── eks/            # EKS cluster, node group, OIDC, IRSA roles
│   │   └── messaging/      # SQS queue + DLQ
│   ├── services/
│   │   └── redemption/
│   │       ├── rds/        # Aurora PostgreSQL, KMS, Secrets Manager
│   │       ├── cache/      # ElastiCache Redis, KMS
│   │       ├── compute/    # ECR, app IRSA role
│   │       └── ingress/    # ALB, WAF, ACM, Route 53
│   └── environments/
│       └── production/     # terraform.tfvars per module
└── kubernetes/
    ├── base/               # Argo Rollout, Services, KEDA, worker Deployment,
    │                       # AnalysisTemplate, ServiceAccount
    ├── overlays/
    │   └── production/     # Kustomize patches, ExternalSecret, PDB, Ingress, ArgoCD app,
    │                       # KEDA ScaledObject (CPU + memory + Flash Sale cron pre-warm)
    └── cluster-tools/
        └── overprovisioning/  # PriorityClass (-1) + pause pod Deployment (node buffer)
```

---

## Deploy order

```
shared/infra → shared/eks → shared/messaging
                          → services/redemption/rds
                          → services/redemption/cache
                          → services/redemption/compute
                          → services/redemption/ingress
```

Cross-stack references are passed through **AWS SSM Parameter Store** — no Terraform remote state sharing between stacks.

See [terraform/README.md](terraform/README.md) for tool setup and per-module validation commands.

After EKS and Karpenter are running, apply the node overprovisioning buffer once:

```bash
kubectl apply -k kubernetes/cluster-tools/overprovisioning/
```

This keeps 3 warm pause pods running permanently so Flash Sale pods evict them instantly instead of waiting for node boot.

---

## Tech stack

| Layer | Technology |
|---|---|
| IaC | Terraform (AWS provider 5.x) |
| Container platform | AWS EKS |
| Deployment strategy | Argo Rollouts (canary) + ArgoCD (GitOps) |
| Autoscaling | KEDA (CPU/memory/cron for HTTP server; SQS depth for worker) + Karpenter (nodes) |
| Database | Aurora PostgreSQL 15.4 |
| Cache | ElastiCache Redis |
| Messaging | Amazon SQS + DLQ |
| Secrets | AWS Secrets Manager + External Secrets Operator |
| Ingress | AWS ALB (AWS Load Balancer Controller) + WAFv2 |
| Observability | Datadog APM + Sentry |
| Manifest templating | Kustomize |
