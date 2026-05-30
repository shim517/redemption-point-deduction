# ── SSM Parameter Store — cross-stack inputs ──────────────────────────────────

data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.env}/shared-infra/vpc-id"
}

data "aws_ssm_parameter" "vpc_cidr_block" {
  name = "/${var.env}/shared-infra/vpc-cidr-block"
}

data "aws_ssm_parameter" "public_subnet_ids" {
  name = "/${var.env}/shared-infra/public-subnet-ids"
}

data "aws_ssm_parameter" "node_sg_id" {
  name = "/${var.env}/shared-eks/node-sg-id"
}

locals {
  vpc_id            = data.aws_ssm_parameter.vpc_id.value
  vpc_cidr          = data.aws_ssm_parameter.vpc_cidr_block.value
  public_subnet_ids = split(",", data.aws_ssm_parameter.public_subnet_ids.value)
  node_sg_id        = data.aws_ssm_parameter.node_sg_id.value
}

# ── ACM Certificate ───────────────────────────────────────────────────────────

resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  tags              = { Name = "redemption-${var.env}-cert" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ── WAF — regional (ALB) ──────────────────────────────────────────────────────

resource "aws_wafv2_web_acl" "alb" {
  name  = "redemption-${var.env}-waf-alb"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimit"
    priority = 1
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "redemption-${var.env}-waf-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesCommon"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "redemption-${var.env}-waf-common"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "redemption-${var.env}-waf-alb"
    sampled_requests_enabled   = true
  }

  tags = { Name = "redemption-${var.env}-waf-alb" }
}

# ── ALB Security Group ────────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "redemption-${var.env}-sg-alb"
  description = "Allow HTTPS/HTTP inbound; forward to EKS nodes"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from internet (redirected to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "Forward to EKS nodes"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [local.node_sg_id]
  }

  tags = { Name = "redemption-${var.env}-sg-alb" }
}

# ── ALB ───────────────────────────────────────────────────────────────────────

resource "aws_lb" "main" {
  name               = "redemption-${var.env}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.public_subnet_ids

  tags = { Name = "redemption-${var.env}-alb" }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_target_group" "main" {
  name        = "redemption-${var.env}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
  }

  tags = { Name = "redemption-${var.env}-tg" }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.alb.arn
}
