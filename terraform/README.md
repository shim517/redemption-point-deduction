# Terraform — Redemption

All commands run from `~/dev/redemption-point-deduction/terraform`.

## Directory structure

```
terraform/
├── shared/
│   ├── infra/          # VPC, subnets, NAT GWs, VPC endpoints
│   └── messaging/      # Amazon SQS (shared across services)
├── services/
│   └── redemption/
│       ├── rds/        # Aurora PostgreSQL
│       ├── cache/      # ElastiCache Redis
│       ├── compute/    # EKS, ECR, IAM
│       └── ingress/    # ALB, WAF
└── environments/
    └── production/
        ├── shared/infra/terraform.tfvars
        ├── shared/messaging/terraform.tfvars
        └── redemption/{rds,cache,compute,ingress}/terraform.tfvars
```

---

## Install tools (once)

```bash
# tflint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# checkov
pip install checkov
```

---

## shared/infra

### Static checks (no AWS credentials needed)

```bash
# Formatting check
terraform fmt -check -recursive

# Syntax + schema validation
terraform -chdir=shared/infra init -backend=false -input=false
terraform -chdir=shared/infra validate

# Naming conventions, deprecated syntax
tflint --chdir=shared/infra --init
tflint --chdir=shared/infra

# Security policy
checkov -d shared/infra --quiet
```

---

## Deploy order

```
shared/infra → shared/messaging → services/redemption/rds
                                → services/redemption/cache
                                → services/redemption/compute
                                → services/redemption/ingress
```
