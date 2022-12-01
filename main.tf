provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIA42KD7CHKJEP5BHG3"
  secret_key = "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"
}


variable "vpc_cidr_blocks" {}
variable "subnet_cidr_blocks" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {}


resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_blocks
  tags = {
    Name : "${var.env_prefix}-vpc"
  }
}

// Custom Subnet //

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id            = aws_vpc.myapp-vpc.id
  cidr_block        = var.subnet_cidr_blocks
  availability_zone = var.avail_zone
  tags = {
    Name : "${var.env_prefix}-subnet1"
  }
}


//This is My custom Internet Gateway //

resource "aws_internet_gateway" "myapp_igw" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    "Name" = "${var.env_prefix}-igw"
  }
}


// Subnet Association with Route table //

resource "aws_default_route_table" "main-rtb" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp_igw.id
  }

  tags = {
    Name = "${var.env_prefix}-main-Route-table"
  }
}

resource "aws_default_security_group" "myapp-sg" {
  vpc_id = aws_vpc.myapp-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]

  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }
  tags = {
    "Name" = "${var.env_prefix}-default-sg"
  }
}

// Fetch a AMi to The Instance //

data "aws_ami" "latest-amazon-amazon-image" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

output "aws_ami_id" {
  value = data.aws_ami.latest-amazon-amazon-image.id
}



resource "aws_instance" "myapp-server" {
  ami           = data.aws_ami.latest-amazon-amazon-image.id
  instance_type = var.instance_type

  subnet_id = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_default_security_group.myapp-sg.id]
  availability_zone = var.avail_zone

  associate_public_ip_address = true
  key_name   = "latest-key-pair"

  user_data = <<EOF
                   #!bin/bash
                   sudo yum update -y
                   sudo yum install docker -y
                   sudo systemctl start docker
                   sudo usermod -aG docker ec2-user
                   docker run -p 8080:80 nginx
                EOF

  tags = {
    "Name" = "${var.env_prefix}-server"
  }
}
