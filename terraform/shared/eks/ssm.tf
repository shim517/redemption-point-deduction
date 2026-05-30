resource "aws_ssm_parameter" "cluster_name" {
  name  = "/${var.env}/shared-eks/cluster-name"
  type  = "String"
  value = aws_eks_cluster.main.name
}

resource "aws_ssm_parameter" "cluster_endpoint" {
  name  = "/${var.env}/shared-eks/cluster-endpoint"
  type  = "String"
  value = aws_eks_cluster.main.endpoint
}

resource "aws_ssm_parameter" "cluster_ca_certificate" {
  name  = "/${var.env}/shared-eks/cluster-ca-certificate"
  type  = "String"
  value = aws_eks_cluster.main.certificate_authority[0].data
}

resource "aws_ssm_parameter" "oidc_provider_arn" {
  name  = "/${var.env}/shared-eks/oidc-provider-arn"
  type  = "String"
  value = aws_iam_openid_connect_provider.main.arn
}

resource "aws_ssm_parameter" "oidc_provider_url" {
  name  = "/${var.env}/shared-eks/oidc-provider-url"
  type  = "String"
  value = replace(aws_iam_openid_connect_provider.main.url, "https://", "")
}

resource "aws_ssm_parameter" "node_sg_id" {
  name  = "/${var.env}/shared-eks/node-sg-id"
  type  = "String"
  value = aws_security_group.nodes.id
}

resource "aws_ssm_parameter" "lbc_role_arn" {
  name  = "/${var.env}/shared-eks/lbc-role-arn"
  type  = "String"
  value = aws_iam_role.lbc.arn
}

resource "aws_ssm_parameter" "eso_role_arn" {
  name  = "/${var.env}/shared-eks/eso-role-arn"
  type  = "String"
  value = aws_iam_role.eso.arn
}

resource "aws_ssm_parameter" "keda_role_arn" {
  name  = "/${var.env}/shared-eks/keda-role-arn"
  type  = "String"
  value = aws_iam_role.keda.arn
}
