# ── SSM Parameter Store — cross-stack inputs ──────────────────────────────────

data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.env}/shared-infra/vpc-id"
}

data "aws_ssm_parameter" "vpc_cidr_block" {
  name = "/${var.env}/shared-infra/vpc-cidr-block"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/${var.env}/shared-infra/private-subnet-ids"
}

locals {
  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  vpc_cidr_block     = data.aws_ssm_parameter.vpc_cidr_block.value
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  cluster_name       = "shared-eks-${var.env}"
}

# ── KMS key for EKS secrets encryption ───────────────────────────────────────

resource "aws_kms_key" "eks" {
  description             = "CMK for EKS cluster secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "shared-eks-${var.env}-kms" }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/shared-eks-${var.env}"
  target_key_id = aws_kms_key.eks.key_id
}

# ── IAM — EKS cluster role ────────────────────────────────────────────────────

resource "aws_iam_role" "cluster" {
  name = "shared-eks-${var.env}-role-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ── IAM — node group role ─────────────────────────────────────────────────────

resource "aws_iam_role" "nodes" {
  name = "shared-eks-${var.env}-role-nodes"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nodes_worker" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "nodes_cni" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "nodes_ecr" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ── Security Groups ───────────────────────────────────────────────────────────

resource "aws_security_group" "nodes" {
  name        = "shared-eks-${var.env}-sg-nodes"
  description = "EKS worker node security group"
  vpc_id      = local.vpc_id

  # All node-to-node traffic within the cluster
  ingress {
    description = "Node to node"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # ALB to nodes (ingress controller traffic); ALB SG added in ingress stack
  ingress {
    description = "HTTPS from within VPC (ALB health checks and traffic)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr_block]
  }

  ingress {
    description = "HTTP from within VPC (ALB health checks)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr_block]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "shared-eks-${var.env}-sg-nodes" }
}

# ── EKS Cluster ───────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.eks_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = local.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = [aws_security_group.nodes.id]
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]

  tags = { Name = local.cluster_name }
}

# ── OIDC Provider (required for IRSA) ─────────────────────────────────────────

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "main" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = { Name = "shared-eks-${var.env}-oidc" }
}

# ── Managed Node Group ────────────────────────────────────────────────────────

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "shared-eks-${var.env}-ng"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = local.private_subnet_ids
  instance_types  = [var.node_instance_type]

  scaling_config {
    min_size     = var.node_min_size
    max_size     = var.node_max_size
    desired_size = var.node_desired_size
  }

  update_config {
    # Roll one node at a time to maintain availability during updates.
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker,
    aws_iam_role_policy_attachment.nodes_cni,
    aws_iam_role_policy_attachment.nodes_ecr,
  ]

  tags = { Name = "shared-eks-${var.env}-ng" }
}

# ── EKS Add-ons ───────────────────────────────────────────────────────────────

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
  tags         = { Name = "shared-eks-${var.env}-addon-vpc-cni" }
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
  tags         = { Name = "shared-eks-${var.env}-addon-coredns" }

  depends_on = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
  tags         = { Name = "shared-eks-${var.env}-addon-kube-proxy" }
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"
  tags         = { Name = "shared-eks-${var.env}-addon-ebs-csi" }

  depends_on = [aws_eks_node_group.main]
}

# ── IRSA — AWS Load Balancer Controller ───────────────────────────────────────

data "aws_iam_policy_document" "lbc_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.main.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.main.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "lbc" {
  name               = "shared-eks-${var.env}-role-lbc"
  assume_role_policy = data.aws_iam_policy_document.lbc_assume.json
  tags               = { Name = "shared-eks-${var.env}-role-lbc" }
}

# Policy document sourced from the official AWS LBC GitHub repo.
# https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
resource "aws_iam_role_policy" "lbc" {
  name = "shared-eks-${var.env}-policy-lbc"
  role = aws_iam_role.lbc.id

  policy = file("${path.module}/policies/lbc.json")
}

# ── IRSA — KEDA Operator ─────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "keda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.main.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.main.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:keda:keda-operator"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.main.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "keda" {
  name               = "shared-eks-${var.env}-role-keda"
  assume_role_policy = data.aws_iam_policy_document.keda_assume.json
  tags               = { Name = "shared-eks-${var.env}-role-keda" }
}

resource "aws_iam_role_policy" "keda" {
  name = "shared-eks-${var.env}-policy-keda"
  role = aws_iam_role.keda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "SqsGetQueueAttributes"
      Effect   = "Allow"
      Action   = ["sqs:GetQueueAttributes"]
      Resource = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:shared-messaging-${var.env}-point-deduction"
    }]
  })
}

# ── IRSA — External Secrets Operator ─────────────────────────────────────────

data "aws_iam_policy_document" "eso_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.main.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.main.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:external-secrets:external-secrets"]
    }
  }
}

resource "aws_iam_role" "eso" {
  name               = "shared-eks-${var.env}-role-eso"
  assume_role_policy = data.aws_iam_policy_document.eso_assume.json
  tags               = { Name = "shared-eks-${var.env}-role-eso" }
}

resource "aws_iam_role_policy" "eso" {
  name = "shared-eks-${var.env}-policy-eso"
  role = aws_iam_role.eso.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SecretsManagerRead"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:*"
      },
      {
        Sid      = "SsmParameterRead"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.env}/*"
      },
    ]
  })
}
