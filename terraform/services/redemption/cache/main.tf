# ── SSM Parameter Store — cross-stack inputs ──────────────────────────────────

data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.env}/shared-infra/vpc-id"
}

data "aws_ssm_parameter" "data_subnet_ids" {
  name = "/${var.env}/shared-infra/data-subnet-ids"
}

data "aws_ssm_parameter" "node_sg_id" {
  name = "/${var.env}/shared-eks/node-sg-id"
}

locals {
  vpc_id          = data.aws_ssm_parameter.vpc_id.value
  data_subnet_ids = split(",", data.aws_ssm_parameter.data_subnet_ids.value)
  node_sg_id      = data.aws_ssm_parameter.node_sg_id.value
}

# ── Auth token ────────────────────────────────────────────────────────────────
# ElastiCache auth token: alphanumeric only (no special characters allowed).

resource "random_password" "redis_auth" {
  length  = 32
  special = false
}

# ── KMS ───────────────────────────────────────────────────────────────────────

resource "aws_kms_key" "cache" {
  description             = "CMK for redemption ElastiCache encryption at rest"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "redemption-${var.env}-kms-cache" }
}

resource "aws_kms_alias" "cache" {
  name          = "alias/redemption-${var.env}-cache"
  target_key_id = aws_kms_key.cache.key_id
}

# ── Security Group ────────────────────────────────────────────────────────────

resource "aws_security_group" "cache" {
  name        = "redemption-${var.env}-sg-cache"
  description = "Allow Redis from EKS worker nodes only"
  vpc_id      = local.vpc_id

  ingress {
    description     = "Redis from EKS nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [local.node_sg_id]
  }

  tags = { Name = "redemption-${var.env}-sg-cache" }
}

# ── ElastiCache Redis (cluster mode) ─────────────────────────────────────────

resource "aws_elasticache_subnet_group" "main" {
  name       = "redemption-${var.env}-cache-subnet-group"
  subnet_ids = local.data_subnet_ids
  tags       = { Name = "redemption-${var.env}-cache-subnet-group" }
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id    = "redemption-${var.env}-cache"
  description             = "Redemption Redis cluster — session, distributed lock, idempotency key"
  node_type               = var.node_type
  num_node_groups         = var.num_node_groups
  replicas_per_node_group = var.replicas_per_node_group

  automatic_failover_enabled = true
  multi_az_enabled           = true
  engine_version             = "7.0"

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.cache.id]

  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.cache.arn
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth.result

  tags = { Name = "redemption-${var.env}-cache" }
}

# ── Secrets Manager — Redis connection URL ────────────────────────────────────

resource "aws_secretsmanager_secret" "cache" {
  name       = "redemption/${var.env}/cache"
  kms_key_id = aws_kms_key.cache.arn
  tags       = { Name = "redemption-${var.env}-secret-cache" }
}

resource "aws_secretsmanager_secret_version" "cache" {
  secret_id = aws_secretsmanager_secret.cache.id
  secret_string = jsonencode({
    url = "rediss://:${random_password.redis_auth.result}@${aws_elasticache_replication_group.main.configuration_endpoint_address}:6379"
  })
}
