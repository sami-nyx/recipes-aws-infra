resource "aws_security_group" "app_sg" {
  name        = "recipes-app-sg-${var.environment}"
  description = "Security group for application/runner instance"
  vpc_id      = var.vpc_id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rules (Allow all)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "recipes-app-sg-${var.environment}"
  }
}


resource "aws_iam_role" "runner_role" {
  name = "github-runner-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "runner_secrets_policy" {
  name        = "github-runner-secrets-policy"
  description = "Allows reading the GitHub PAT for runner auto-registration"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = "arn:aws:secretsmanager:ap-south-1:889867978066:secret:github/runner-pat-jVcp7l"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_secrets" {
  role       = aws_iam_role.runner_role.name
  policy_arn = aws_iam_policy.runner_secrets_policy.arn
}

resource "aws_iam_instance_profile" "runner_profile" {
  name = "github-runner-instance-profile"
  role = aws_iam_role.runner_role.name
}