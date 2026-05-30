variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "env" {
  type        = string
  description = "Environment name (staging, production)"
}

variable "eks_version" {
  type        = string
  description = "Kubernetes version for the EKS cluster (e.g. 1.30)"
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for EKS worker nodes (e.g. t3.medium)"
}

variable "node_min_size" {
  type        = number
  description = "Minimum number of worker nodes across all AZs"
}

variable "node_max_size" {
  type        = number
  description = "Maximum number of worker nodes (autoscaling ceiling)"
}

variable "node_desired_size" {
  type        = number
  description = "Initial desired number of worker nodes"
}
