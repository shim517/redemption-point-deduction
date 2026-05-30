variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "env" {
  type        = string
  description = "Environment name (staging, production)"
}

variable "domain_name" {
  type        = string
  description = "Public domain name for the service (e.g. redemption.example.com)"
}

variable "route53_zone_id" {
  type        = string
  description = "Route53 hosted zone ID for DNS validation of the ACM certificate"
}

variable "waf_rate_limit" {
  type        = number
  description = "Max requests per 5 minutes per IP before WAF blocks (ALB WAF)"
  default     = 3000
}
