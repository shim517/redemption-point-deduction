variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "env" {
  type        = string
  description = "Environment name (staging, production)"
}

variable "visibility_timeout_seconds" {
  type        = number
  description = "SQS message visibility timeout in seconds"
  default     = 30
}

variable "max_receive_count" {
  type        = number
  description = "Number of times a message is delivered before being moved to the DLQ"
  default     = 5
}
