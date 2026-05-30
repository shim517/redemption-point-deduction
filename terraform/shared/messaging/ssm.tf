resource "aws_ssm_parameter" "queue_url" {
  name  = "/${var.env}/shared-messaging/sqs-queue-url"
  type  = "String"
  value = aws_sqs_queue.main.url
}

resource "aws_ssm_parameter" "queue_arn" {
  name  = "/${var.env}/shared-messaging/sqs-queue-arn"
  type  = "String"
  value = aws_sqs_queue.main.arn
}

resource "aws_ssm_parameter" "dlq_arn" {
  name  = "/${var.env}/shared-messaging/sqs-dlq-arn"
  type  = "String"
  value = aws_sqs_queue.dlq.arn
}
