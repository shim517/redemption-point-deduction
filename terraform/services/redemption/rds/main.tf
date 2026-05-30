# ── SSM Parameter Store — cross-stack inputs ──────────────────────────────────

data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.env}/shared-infra/vpc-id"
}

data "aws_ssm_parameter" "vpc_cidr_block" {
  name = "/${var.env}/shared-infra/vpc-cidr-block"
}

data "aws_ssm_parameter" "data_subnet_ids" {
  name = "/${var.env}/shared-infra/data-subnet-ids"
}

data "aws_ssm_parameter" "node_sg_id" {
  name = "/${var.env}/shared-eks/node-sg-id"
}

locals {
  vpc_id          = data.aws_ssm_parameter.vpc_id.value
  vpc_cidr        = data.aws_ssm_parameter.vpc_cidr_block.value
  data_subnet_ids = split(",", data.aws_ssm_parameter.data_subnet_ids.value)
  node_sg_id      = data.aws_ssm_parameter.node_sg_id.value
}

# ── KMS ───────────────────────────────────────────────────────────────────────

resource "aws_kms_key" "rds" {
  description             = "CMK for redemption RDS Aurora encryption at rest"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "redemption-${var.env}-kms-rds" }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/redemption-${var.env}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ── Credentials ──────────────────────────────────────────────────────────────

resource "random_password" "rds" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_kms_key" "secrets" {
  description             = "CMK for redemption RDS Secrets Manager"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "redemption-${var.env}-kms-rds-secrets" }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/redemption-${var.env}-rds-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_secretsmanager_secret" "rds" {
  name       = "redemption/${var.env}/rds"
  kms_key_id = aws_kms_key.secrets.arn
  tags       = { Name = "redemption-${var.env}-secret-rds" }
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.rds.result
    engine   = "aurora-postgresql"
    port     = 5432
  })
}

# ── Security Group ───────────────────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "redemption-${var.env}-sg-rds"
  description = "Allow PostgreSQL from EKS worker nodes only"
  vpc_id      = local.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [local.node_sg_id]
  }

  tags = { Name = "redemption-${var.env}-sg-rds" }
}

# ── Aurora PostgreSQL ─────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "main" {
  name       = "redemption-${var.env}-rds-subnet-group"
  subnet_ids = local.data_subnet_ids
  tags       = { Name = "redemption-${var.env}-rds-subnet-group" }
}

resource "aws_rds_cluster" "main" {
  cluster_identifier     = "redemption-${var.env}-rds"
  engine                 = "aurora-postgresql"
  engine_version         = "15.4"
  database_name          = "redemption"
  master_username        = var.master_username
  master_password        = random_password.rds.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  kms_key_id             = aws_kms_key.rds.arn
  storage_encrypted      = true

  backup_retention_period   = 7
  preferred_backup_window   = "03:00-04:00"
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "redemption-${var.env}-rds-final"

  tags = { Name = "redemption-${var.env}-rds" }
}

resource "aws_rds_cluster_instance" "main" {
  count = var.instance_count

  identifier         = "redemption-${var.env}-rds-${count.index == 0 ? "writer" : "reader"}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  # Lower tier = higher promotion priority; index 0 acts as the initial writer.
  promotion_tier = count.index

  tags = { Name = "redemption-${var.env}-rds-${count.index == 0 ? "writer" : "reader"}" }
}

# ── Aurora Reader Auto Scaling ────────────────────────────────────────────────

resource "aws_appautoscaling_target" "rds_readers" {
  service_namespace  = "rds"
  resource_id        = "cluster:${aws_rds_cluster.main.cluster_identifier}"
  scalable_dimension = "rds:cluster:ReadReplicaCount"
  min_capacity       = 1
  max_capacity       = var.reader_max_count

  depends_on = [aws_rds_cluster_instance.main]
}

resource "aws_appautoscaling_policy" "rds_cpu" {
  name               = "redemption-${var.env}-rds-reader-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.rds_readers.resource_id
  scalable_dimension = aws_appautoscaling_target.rds_readers.scalable_dimension
  service_namespace  = aws_appautoscaling_target.rds_readers.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "RDSReaderAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 120
  }
}
