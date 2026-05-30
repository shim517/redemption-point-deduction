variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "env" {
  type        = string
  description = "Environment name (dev, staging, production)"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "azs" {
  type        = list(string)
  description = "List of availability zones (must be exactly 3)"

  validation {
    condition     = length(var.azs) == 3
    error_message = "Exactly 3 availability zones are required."
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets, one per AZ"

  validation {
    condition     = length(var.public_subnet_cidrs) == 3
    error_message = "Exactly 3 public subnet CIDRs are required."
  }
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for EKS private subnets, one per AZ"

  validation {
    condition     = length(var.private_subnet_cidrs) == 3
    error_message = "Exactly 3 private subnet CIDRs are required."
  }
}

variable "data_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for data-tier subnets (RDS, ElastiCache, VPC endpoints), one per AZ"

  validation {
    condition     = length(var.data_subnet_cidrs) == 3
    error_message = "Exactly 3 data subnet CIDRs are required."
  }
}
