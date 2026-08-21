resource "aws_eks_cluster" "this"{
    name = "${var.owner}-cluster"
    version= 1.36    
    region= var.region
access_config {
    authentication_mode = "API"
  }

    vpc_config {
      subnet_ids = var.subnet_ids
    }
    role_arn = aws_iam_role.cluster_role.arn


 
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
