resource "aws_db_subnet_group" "recipes" {
  name       = "recipes-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "recipes-db-subnet-group"
  }
}

data "aws_rds_engine_version" "engine" {
  engine  = var.db_engine
  version = var.db_engine_version
}

resource "aws_db_instance" "rds_db" {
  identifier = "recipes-db"

  engine         = data.aws_rds_engine_version.engine.engine
  engine_version = data.aws_rds_engine_version.engine.version

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  instance_class    = var.db_instance_class

  db_name  = var.db_name
  username = var.db_username

  db_subnet_group_name   = aws_db_subnet_group.recipes.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  publicly_accessible = false

  storage_encrypted           = true
  manage_master_user_password = true

  backup_retention_period = var.db_backup_retention_period
  deletion_protection     = var.db_deletion_protection

  skip_final_snapshot = var.db_skip_final_snapshot

  tags = {
    Name = "recipes-db"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "recipes-rds-sg"
  description = "Allow PostgreSQL from EKS worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.node_sg_id]
  }

  egress {
    description = "RDS outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "recipes-rds-sg"
  }
}
# resource "aws_db_subnet_group" "recipes" {
#   name       = "recipes-db-subnet-group"
#   subnet_ids = var.private_subnet_ids

#   tags = {
#     Name = "recipes-db-subnet-group"
#   }
# }

# data "aws_rds_engine_version" "engine" {
#   engine  = var.db_engine
#   version = var.db_engine_version
# }

# resource "aws_db_instance" "rds_db" {
#   identifier          = "recipes-db"
#   engine              = data.aws_rds_engine_version.engine.engine
#   engine_version      = data.aws_rds_engine_version.engine.version
#   allocated_storage   = var.db_allocated_storage
#   storage_type        = "gp3"
#   db_name             = var.db_name
#   instance_class      = var.db_instance_class
#   username            = var.db_username
#   skip_final_snapshot = var.db_skip_final_snapshot

#   # Networking & Security bindings
#   db_subnet_group_name   = aws_db_subnet_group.recipes.name
#   vpc_security_group_ids = [aws_security_group.rds_sg.id]
#   # Encryption & Credentials
#   manage_master_user_password = true
#   storage_encrypted           = true
#   publicly_accessible = false
#   backup_retention_period = 7

#   tags = {
#     Name = "recipes-db"
#   }
# }

# resource "aws_security_group" "rds_sg" {
#   name        = "recipes-rds-sg"
#   description = "Allow inbound traffic from EKS worker nodes to PostgreSQL"
#   vpc_id      = var.vpc_id

#   ingress {
#     description     = "PostgreSQL from EKS nodes"
#     from_port       = 5432
#     to_port         = 5432
#     protocol        = "tcp"
#     security_groups = [var.node_sg_id]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }