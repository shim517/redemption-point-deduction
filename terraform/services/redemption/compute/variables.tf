variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "env" {
  type        = string
  description = "Environment name (staging, production)"
}

variable "k8s_namespace" {
  type        = string
  description = "Kubernetes namespace where the redemption app runs"
  default     = "redemption"
}

variable "k8s_service_account" {
  type        = string
  description = "Kubernetes service account name for the redemption app"
  default     = "redemption"
}
