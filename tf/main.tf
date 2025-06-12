# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.environment}-public-subnet-${count.index + 1}"
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 3)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.environment}-private-subnet-${count.index + 1}"
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-igw"
    Environment = var.environment
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.environment}-nat-eip"
    Environment = var.environment
  }
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.environment}-nat"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.environment}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.environment}-private-rt"
    Environment = var.environment
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security Groups
resource "aws_security_group" "bastion" {
  name        = "${var.environment}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-bastion-sg"
    Environment = var.environment
  }
}

data "aws_security_group" "bastion" {
  filter {
    name   = "tag:Name"
    values = ["${var.environment}-bastion-sg"]
  }
  depends_on = [aws_security_group.bastion]
}

resource "aws_security_group" "mirror" {
  name        = "${var.environment}-mirror-sg"
  description = "Security group for mirror host"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Internal traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-mirror-sg"
    Environment = var.environment
  }
}

# EC2 Instances
resource "aws_instance" "bastion" {
  ami           = var.rhel9_ami_id
  instance_type = var.bastion_instance_type
  subnet_id     = aws_subnet.public[0].id
  key_name      = var.key_name

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  vpc_security_group_ids = [aws_security_group.bastion.id]

  user_data = <<-EOF
              #!/bin/bash
              dnf install -y vim jq wget
              # Install OpenShift CLI
              wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
              tar xvf openshift-client-linux.tar.gz
              chmod +x oc
              mv oc /usr/local/bin/
              rm openshift-client-linux.tar.gz
              # Install OpenShift Installer
              wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.16.42/openshift-install-linux.tar.gz
              tar xvf openshift-install-linux.tar.gz
              chmod +x openshift-install
              mv openshift-install /usr/local/bin/
              rm openshift-install-linux.tar.gz
              EOF

  tags = {
    Name        = "${var.environment}-bastion"
    Environment = var.environment
  }
}

resource "aws_instance" "mirror" {
  ami           = var.rhel9_ami_id
  instance_type = var.mirror_instance_type
  subnet_id     = aws_subnet.public[0].id
  key_name      = var.key_name

  root_block_device {
    volume_size = 1000
    volume_type = "gp3"
  }

  vpc_security_group_ids = [aws_security_group.mirror.id]

  user_data = <<-EOF
              #!/bin/bash
              dnf install -y vim jq wget
              # Install OpenShift CLI
              wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
              tar xvf openshift-client-linux.tar.gz
              chmod +x oc
              mv oc /usr/local/bin/
              rm openshift-client-linux.tar.gz
              # Install mirror-registry
              wget https://mirror.openshift.com/pub/openshift-v4/dependencies/tools/latest/linux/mirror-registry.tar.gz
              tar xvf mirror-registry.tar.gz
              chmod +x mirror-registry
              rm mirror-registry.tar.gz
              # Install oc-mirror
              wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/oc-mirror.tar.gz
              tar xvf oc-mirror.tar.gz
              chmod +x oc-mirror
              mv oc-mirror /usr/local/bin/
              rm oc-mirror.tar.gz
              EOF

  tags = {
    Name        = "${var.environment}-mirror"
    Environment = var.environment
  }
}

# Elastic IPs
resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = {
    Name        = "${var.environment}-bastion-eip"
    Environment = var.environment
  }
}

resource "aws_eip" "mirror" {
  instance = aws_instance.mirror.id
  domain   = "vpc"

  tags = {
    Name        = "${var.environment}-mirror-eip"
    Environment = var.environment
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
} 