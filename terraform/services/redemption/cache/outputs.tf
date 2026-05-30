output "configuration_endpoint" {
  description = "Redis cluster mode configuration endpoint"
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address
}

output "cache_sg_id" {
  description = "ElastiCache security group ID"
  value       = aws_security_group.cache.id
}

output "secret_arn" {
  description = "Secrets Manager ARN for Redis connection URL"
  value       = aws_secretsmanager_secret.cache.arn
}
