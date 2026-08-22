resource "aws_eks_cluster" "this" {
  name    = "${var.owner}-cluster"
  version = 1.36
  region  = var.region
  access_config {
    authentication_mode = "API"
  }

  vpc_config {
    subnet_ids = var.nodes_in_public ? var.public_subnet_ids : concat(var.private_subnet_ids, var.public_subnet_ids)
  }
  role_arn = aws_iam_role.cluster_role.arn
  depends_on = [
  aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy
]
}

resource "aws_vpc_security_group_ingress_rule" "cluster_from_nodes_https" {
  security_group_id            = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.node_sg.id

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  description = "Allow EKS worker nodes to reach Kubernetes API"
}
resource "aws_iam_role" "cluster_role" {
  name = "${var.name_prefix}-eks-cluster-roe"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}
