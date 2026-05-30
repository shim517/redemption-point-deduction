output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider (used by service stacks to create IRSA roles)"
  value       = aws_iam_openid_connect_provider.main.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider (without https://)"
  value       = replace(aws_iam_openid_connect_provider.main.url, "https://", "")
}

output "node_sg_id" {
  description = "Security group ID of the worker nodes (referenced by data-tier SG rules)"
  value       = aws_security_group.nodes.id
}

output "lbc_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller"
  value       = aws_iam_role.lbc.arn
}

output "eso_role_arn" {
  description = "IAM role ARN for the External Secrets Operator"
  value       = aws_iam_role.eso.arn
}

output "keda_role_arn" {
  description = "IAM role ARN for the KEDA operator (annotate keda/keda-operator service account)"
  value       = aws_iam_role.keda.arn
}
