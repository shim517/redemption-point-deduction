# ── SQS Dead-Letter Queue ─────────────────────────────────────────────────────

resource "aws_sqs_queue" "dlq" {
  name                      = "shared-messaging-${var.env}-point-deduction-dlq"
  message_retention_seconds = 1209600 # 14 days
  sqs_managed_sse_enabled   = true

  tags = { Name = "shared-messaging-${var.env}-point-deduction-dlq" }
}

# ── SQS Main Queue ────────────────────────────────────────────────────────────

resource "aws_sqs_queue" "main" {
  name                       = "shared-messaging-${var.env}-point-deduction"
  visibility_timeout_seconds = var.visibility_timeout_seconds
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = { Name = "shared-messaging-${var.env}-point-deduction" }
}

# Allow the DLQ to accept messages redriven from the main queue.
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.main.arn]
  })
}
