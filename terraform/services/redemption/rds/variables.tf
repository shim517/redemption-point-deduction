variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "env" {
  type        = string
  description = "Environment name (staging, production)"
}

variable "instance_class" {
  type        = string
  description = "Aurora instance class for writer and reader (e.g. db.r6g.large)"
}

variable "master_username" {
  type        = string
  description = "Master username for the Aurora cluster"
  default     = "redemption"
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection. Set false only to tear down the cluster."
  default     = true
}

variable "instance_count" {
  type        = number
  description = "Number of Aurora instances (1 writer + N-1 readers). Minimum 1."
  default     = 2
}

variable "reader_max_count" {
  type        = number
  description = "Maximum number of Aurora reader instances auto-scaling can add."
  default     = 4
}
