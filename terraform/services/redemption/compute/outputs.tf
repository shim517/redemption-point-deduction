output "ecr_repository_url" {
  description = "ECR repository URL for pushing redemption images"
  value       = aws_ecr_repository.main.repository_url
}

output "app_role_arn" {
  description = "IRSA role ARN to annotate the redemption Kubernetes service account with"
  value       = aws_iam_role.app.arn
}
