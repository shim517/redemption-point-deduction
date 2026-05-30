output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (one per AZ)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the EKS private subnets (one per AZ)"
  value       = aws_subnet.private[*].id
}

output "data_subnet_ids" {
  description = "IDs of the data-tier subnets — RDS, ElastiCache, VPC endpoints (one per AZ)"
  value       = aws_subnet.data[*].id
}

output "vpc_endpoint_sg_id" {
  description = "Security group ID attached to all VPC interface endpoints"
  value       = aws_security_group.vpc_endpoints.id
}
