# ── SSM Parameter Store — cross-stack inputs ──────────────────────────────────

data "aws_ssm_parameter" "oidc_provider_arn" {
  name = "/${var.env}/shared-eks/oidc-provider-arn"
}

data "aws_ssm_parameter" "oidc_provider_url" {
  name = "/${var.env}/shared-eks/oidc-provider-url"
}

data "aws_ssm_parameter" "rds_secret_arn" {
  name = "/${var.env}/redemption-rds/secret-arn"
}

data "aws_ssm_parameter" "sqs_queue_arn" {
  name = "/${var.env}/shared-messaging/sqs-queue-arn"
}

data "aws_ssm_parameter" "sqs_queue_url" {
  name = "/${var.env}/shared-messaging/sqs-queue-url"
}

locals {
  oidc_provider_arn = data.aws_ssm_parameter.oidc_provider_arn.value
  oidc_provider_url = data.aws_ssm_parameter.oidc_provider_url.value
}

# ── ECR ───────────────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "main" {
  name                 = "redemption"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "redemption-${var.env}-ecr" }
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 20 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}

# ── IRSA — redemption app pods ────────────────────────────────────────────────

data "aws_iam_policy_document" "app_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "redemption-${var.env}-role-app"
  assume_role_policy = data.aws_iam_policy_document.app_assume.json
  tags               = { Name = "redemption-${var.env}-role-app" }
}

resource "aws_iam_role_policy" "app" {
  name = "redemption-${var.env}-policy-app"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadRdsSecret"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [
          data.aws_ssm_parameter.rds_secret_arn.value,
        ]
      },
      {
        Sid    = "SqsConsume"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueAttributes",
        ]
        Resource = [data.aws_ssm_parameter.sqs_queue_arn.value]
      },
      {
        Sid      = "SqsProduce"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:GetQueueUrl"]
        Resource = [data.aws_ssm_parameter.sqs_queue_arn.value]
      },
    ]
  })
}
