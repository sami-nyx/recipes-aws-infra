

data "aws_ssm_parameter" "eks_ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${aws_eks_cluster.this.version}/amazon-linux-2023/x86_64/standard/recommended/release_version"
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name_prefix}-default-node-group"
  version         = aws_eks_cluster.this.version
  release_version = nonsensitive(data.aws_ssm_parameter.eks_ami_release_version.value)
  node_role_arn   = aws_iam_role.worker_node_role.arn
  subnet_ids      = var.nodes_in_public ? var.public_subnet_ids : var.private_subnet_ids
  launch_template {
    id      = aws_launch_template.node_lt.id
    version = aws_launch_template.node_lt.latest_version
  }
  scaling_config {
    min_size     = var.node_counts.min
    desired_size = var.node_counts.desired
    max_size     = var.node_counts.max
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
  instance_types = [var.node_type]
}



resource "aws_iam_role" "worker_node_role" {
  name = "eks-worker-node-role-${aws_eks_cluster.this.name}"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}





resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.worker_node_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.worker_node_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.worker_node_role.name
}


resource "aws_security_group" "node_sg" {
  name        = "${var.name_prefix}-eks-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  # Node-to-node traffic
  ingress {
    description = "Node to node communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # EKS control plane -> kubelet
  ingress {
    description     = "EKS control plane to kubelet"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
  }

  # Node outbound traffic
  egress {
    description = "Worker node outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-eks-node-sg"
  }
}


resource "aws_launch_template" "node_lt" {
  name_prefix = "${var.name_prefix}-node-lt"
  vpc_security_group_ids = [aws_security_group.node_sg.id]
}