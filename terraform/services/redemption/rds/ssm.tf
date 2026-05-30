resource "aws_ssm_parameter" "writer_endpoint" {
  name  = "/${var.env}/redemption-rds/writer-endpoint"
  type  = "String"
  value = aws_rds_cluster.main.endpoint
}

resource "aws_ssm_parameter" "reader_endpoint" {
  name  = "/${var.env}/redemption-rds/reader-endpoint"
  type  = "String"
  value = aws_rds_cluster.main.reader_endpoint
}

resource "aws_ssm_parameter" "rds_sg_id" {
  name  = "/${var.env}/redemption-rds/sg-id"
  type  = "String"
  value = aws_security_group.rds.id
}

resource "aws_ssm_parameter" "secret_arn" {
  name  = "/${var.env}/redemption-rds/secret-arn"
  type  = "String"
  value = aws_secretsmanager_secret.rds.arn
}
