# List of availability zones in the current region
data "aws_availability_zones" "available" {
  state = "available"
}



locals {
  subnets_count = min(var.ha, length(data.aws_availability_zones.available.names))
}
####### VPC part ####### 

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidrs
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name_prefix}-VPC"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name_prefix}-igw"
  }
}



#=========================================== route tables ======================================================
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}


resource "aws_route_table" "private_rt" {
  count  = var.nodes_in_public ? 0 : 1
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

#=========================================== subnets ======================================================
resource "aws_subnet" "public_subnets" {
  count                   = local.subnets_count
  vpc_id                  = aws_vpc.this.id
  map_public_ip_on_launch = true
  cidr_block              = cidrsubnet(var.vpc_cidrs, 8, count.index * 2)
  availability_zone       = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  tags = {
    Name                     = "${var.name_prefix}-public-subnet-${count.index}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = var.nodes_in_public ? 0 : local.subnets_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidrs, 8, (count.index * 2) + 1)
  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  tags = {
    Name                              = "${var.name_prefix}-private-subnet-${count.index}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}


#======================================= subnets associations ==============================================
resource "aws_route_table_association" "public_rt_association" {
  count          = local.subnets_count
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_rt_association" {
  count          = var.nodes_in_public ? 0 : local.subnets_count
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt[0].id
}

#=========================================== NAT Gateway (Optional) ======================================

resource "aws_eip" "nat" {
  count  = var.nodes_in_public ? 0 : 1
  domain = "vpc"
  tags = {
    Name = "${var.name_prefix}-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  count         = var.nodes_in_public ? 0 : 1
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public_subnets[0].id
  tags = {
    Name = "${var.name_prefix}-nat-gw"
  }
}

resource "aws_route" "private_nat_gateway" {
  count                  = var.nodes_in_public ? 0 : 1
  route_table_id         = aws_route_table.private_rt[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}