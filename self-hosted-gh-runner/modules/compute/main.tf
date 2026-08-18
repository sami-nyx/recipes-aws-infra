data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.runner_instance_profile_name
  user_data = templatefile("${path.module}/templates/userdata.sh.tftpl", {
    aws_region     = var.aws_region
    repo_owner     = var.repo_owner
    repo_name      = var.repo_name
    secret_id      = "github/runner-pat"
    runner_version = var.runner_version
    runner_name    = var.runner_name
    docker_compose_version=var.docker_compose_version
    docker_version = var.docker_version
  })

  user_data_replace_on_change = true

  tags = {
    Name        = "recipes-server-${var.environment}"
    Environment = var.environment
    runner_name = "${var.runner_name}.${var.runner_version}"
    docker_compose_version= var.docker_compose_version
    docker_version= var.docker_version
  }
}