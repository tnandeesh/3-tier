# Versions 
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.40.0"
    }
  }
}

# Authentication to AWS from Terraform code
provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

terraform {
  backend "s3" {
    bucket = "3tier-arch"
    key    = "projects_statefile/infra_dev/terraform.state"
    region = "us-east-1"
  }
}

# VPC 
resource "aws_vpc" "threetier_vpc" {
  cidr_block           = var.cidr_block
  instance_tenancy     = var.instance_tenancy
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    Name       = "threetier_vpc"
    Created_By = "Terraform"
  }
}

# Subnet
resource "aws_subnet" "websubnet1" {
  vpc_id            = aws_vpc.threetier_vpc.id
  cidr_block        = "10.0.1.0/28"
  availability_zone = "us-east-1a"

  tags = {
    Name       = "websubnet1"
    created_by = "Terraform"
  }
}
resource "aws_subnet" "websubnet2" {
  vpc_id            = aws_vpc.threetier_vpc.id
  cidr_block        = "10.0.2.0/28"
  availability_zone = "us-east-1b"

  tags = {
    Name       = "websubnet2"
    created_by = "Terraform"
  }
}

# Private 
resource "aws_subnet" "appsubnet1" {
  vpc_id            = aws_vpc.threetier_vpc.id
  cidr_block        = "10.0.3.0/28"
  availability_zone = "us-east-1a"

  tags = {
    Name       = "appsubnet1"
    created_by = "Terraform"
  }
}
resource "aws_subnet" "appsubnet2" {
  vpc_id            = aws_vpc.threetier_vpc.id
  cidr_block        = "10.0.4.0/28"
  availability_zone = "us-east-1b"

  tags = {
    Name       = "appsubnet2"
    created_by = "Terraform"
  }
}
resource "aws_subnet" "dbsubnet1" {
  vpc_id            = aws_vpc.threetier_vpc.id
  cidr_block        = "10.0.5.0/28"
  availability_zone = "us-east-1a"

  tags = {
    Name       = "dbsubnet1"
    created_by = "Terraform"
  }
}
resource "aws_subnet" "dbsubnet2" {
  vpc_id            = aws_vpc.threetier_vpc.id
  cidr_block        = "10.0.6.0/28"
  availability_zone = "us-east-1b"

  tags = {
    Name       = "dbsubnet2"
    created_by = "Terraform"
  }
}
resource "aws_subnet" "publicsubnet1" {
  vpc_id                  = aws_vpc.threetier_vpc.id
  cidr_block              = "10.0.7.0/28"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"


  tags = {
    Name       = "publicsubnet1"
    created_by = "Terraform"
  }
}


resource "aws_subnet" "publicsubnet2" {
  vpc_id                  = aws_vpc.threetier_vpc.id
  cidr_block              = "10.0.8.0/28"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags = {
    Name       = "publicsubnet2"
    created_by = "Terraform"
  }
}

# Internet gateway for our VPC:

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.threetier_vpc.id

  tags = {
    Name = "Internet Gateway"
  }
}


# Create Public Route Table

resource "aws_route_table" "public_rt_table" {
  vpc_id = aws_vpc.threetier_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rtb"
  }

}

# Public Route Table Associations:

resource "aws_route_table_association" "psb1-association" {
  subnet_id      = aws_subnet.publicsubnet1.id
  route_table_id = aws_route_table.public_rt_table.id
}

resource "aws_route_table_association" "psb2-association" {
  subnet_id      = aws_subnet.publicsubnet2.id
  route_table_id = aws_route_table.public_rt_table.id
}



# NAT Gateway

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.elastic_ip.id
  subnet_id     = aws_subnet.publicsubnet1.id
  depends_on    = [aws_eip.elastic_ip]

  tags = {
    Name = "NAT Gateway"
  }

}

# Elastic IP:

resource "aws_eip" "elastic_ip" {
  vpc = true

  tags = {
    Name = "Elastic IP"
  }

}

# Private Routing Tables:

resource "aws_route_table" "private_rt_table" {
  vpc_id = aws_vpc.threetier_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "private-rtb"
  }
}

# Private Route Table Associations:

resource "aws_route_table_association" "asb1-association" {
  subnet_id      = aws_subnet.appsubnet1.id
  route_table_id = aws_route_table.private_rt_table.id
}

resource "aws_route_table_association" "asb2-association" {
  subnet_id      = aws_subnet.appsubnet2.id
  route_table_id = aws_route_table.private_rt_table.id
}

resource "aws_route_table_association" "wsb1-association" {
  subnet_id      = aws_subnet.websubnet1.id
  route_table_id = aws_route_table.private_rt_table.id
}

resource "aws_route_table_association" "wsb2-association" {
  subnet_id      = aws_subnet.websubnet2.id
  route_table_id = aws_route_table.private_rt_table.id
}

resource "aws_route_table_association" "dbs1-association" {
  subnet_id      = aws_subnet.dbsubnet1.id
  route_table_id = aws_route_table.private_rt_table.id
}

resource "aws_route_table_association" "dbs2-association" {
  subnet_id      = aws_subnet.dbsubnet2.id
  route_table_id = aws_route_table.private_rt_table.id
}



# EC2 Instance for Public Subnets (AutoScaling Yet to be Added....)

resource "aws_instance" "linux-bastion-host" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.publicsubnet1.id
  vpc_security_group_ids = [ aws_security_group.ec2-sgroup.id ]
  iam_instance_profile   = var.iam_instance_profile
  tags = {
    Name      = "Linux-bastion"
    CreatedBy = "Terraform"
  }
}

# EC2 Instance for Private Subnets (AutoScaling Yet to be Added....)

resource "aws_instance" "Application-Server" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.appsubnet1.id
  vpc_security_group_ids = [ aws_security_group.ec2-sgroup.id ]
  iam_instance_profile   = var.iam_instance_profile
  tags = {
    Name      = "App Server 1"
    CreatedBy = "Terraform"
  }
}


resource "aws_instance" "WebServer" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.websubnet1.id
  vpc_security_group_ids = [ aws_security_group.ec2-sgroup.id ]
  iam_instance_profile   = var.iam_instance_profile
  tags = {
    Name      = "Webserver 1"
    CreatedBy = "Terraform"
  }
}

resource "aws_instance" "Database-Server" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.dbsubnet1.id
  vpc_security_group_ids = [ aws_security_group.ec2-sgroup.id ]
  iam_instance_profile   = var.iam_instance_profile
  tags = {
    Name      = "Database Server 1"
    CreatedBy = "Terraform"
  }
}

# Security Group for the VPC:

resource "aws_security_group" "ec2-sgroup" {
  name        = "EC2 Security group"
  description = "Security Group for all the EC2 Instances"
  vpc_id = aws_vpc.threetier_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from any IP address
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow RDP from any IP address
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP from any IP address
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTPS from any IP address
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all Outbound Traffic
  }
}
