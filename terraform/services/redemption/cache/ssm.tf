resource "aws_ssm_parameter" "configuration_endpoint" {
  name  = "/${var.env}/redemption-cache/configuration-endpoint"
  type  = "String"
  value = aws_elasticache_replication_group.main.configuration_endpoint_address
}

resource "aws_ssm_parameter" "cache_sg_id" {
  name  = "/${var.env}/redemption-cache/sg-id"
  type  = "String"
  value = aws_security_group.cache.id
}

resource "aws_ssm_parameter" "secret_arn" {
  name  = "/${var.env}/redemption-cache/secret-arn"
  type  = "String"
  value = aws_secretsmanager_secret.cache.arn
}
