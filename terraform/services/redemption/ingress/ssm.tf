resource "aws_ssm_parameter" "alb_dns_name" {
  name  = "/${var.env}/redemption-ingress/alb-dns-name"
  type  = "String"
  value = aws_lb.main.dns_name
}

resource "aws_ssm_parameter" "alb_sg_id" {
  name  = "/${var.env}/redemption-ingress/alb-sg-id"
  type  = "String"
  value = aws_security_group.alb.id
}

