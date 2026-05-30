variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "env" {
  type        = string
  description = "Environment name (staging, production)"
}

variable "node_type" {
  type        = string
  description = "ElastiCache node type (e.g. cache.r6g.large)"
}

variable "num_node_groups" {
  type        = number
  description = "Number of Redis shards (node groups)"
}

variable "replicas_per_node_group" {
  type        = number
  description = "Number of read replicas per shard"
}
