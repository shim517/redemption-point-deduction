resource "aws_ssm_parameter" "ecr_repository_url" {
  name  = "/${var.env}/redemption-compute/ecr-repository-url"
  type  = "String"
  value = aws_ecr_repository.main.repository_url
}

resource "aws_ssm_parameter" "app_role_arn" {
  name  = "/${var.env}/redemption-compute/app-role-arn"
  type  = "String"
  value = aws_iam_role.app.arn
}

resource "aws_ssm_parameter" "sqs_queue_url" {
  name  = "/${var.env}/redemption-compute/sqs-queue-url"
  type  = "String"
  value = data.aws_ssm_parameter.sqs_queue_url.value
}
