resource "aws_ssm_parameter" "vpc_id" {
  name  = "/${var.env}/shared-infra/vpc-id"
  type  = "String" #checkov:skip=CKV2_AWS_34: non-sensitive infrastructure ID
  value = aws_vpc.main.id
}

resource "aws_ssm_parameter" "vpc_cidr_block" {
  name  = "/${var.env}/shared-infra/vpc-cidr-block"
  type  = "String" #checkov:skip=CKV2_AWS_34: non-sensitive infrastructure ID
  value = aws_vpc.main.cidr_block
}

resource "aws_ssm_parameter" "public_subnet_ids" {
  name  = "/${var.env}/shared-infra/public-subnet-ids"
  type  = "String" #checkov:skip=CKV2_AWS_34: non-sensitive infrastructure ID
  value = join(",", aws_subnet.public[*].id)
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/${var.env}/shared-infra/private-subnet-ids"
  type  = "String" #checkov:skip=CKV2_AWS_34: non-sensitive infrastructure ID
  value = join(",", aws_subnet.private[*].id)
}

resource "aws_ssm_parameter" "data_subnet_ids" {
  name  = "/${var.env}/shared-infra/data-subnet-ids"
  type  = "String" #checkov:skip=CKV2_AWS_34: non-sensitive infrastructure ID
  value = join(",", aws_subnet.data[*].id)
}

resource "aws_ssm_parameter" "vpc_endpoint_sg_id" {
  name  = "/${var.env}/shared-infra/vpc-endpoint-sg-id"
  type  = "String" #checkov:skip=CKV2_AWS_34: non-sensitive infrastructure ID
  value = aws_security_group.vpc_endpoints.id
}
