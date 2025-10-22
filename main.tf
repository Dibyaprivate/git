provider "aws" {
  region = var.region
}

#########################
# 1. VPC
#########################
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

#########################
# 2. Subnets (2 Public, 2 Private)
#########################
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-b"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.region}a"
  tags = {
    Name = "private-subnet-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.region}b"
  tags = {
    Name = "private-subnet-b"
  }
}

#########################
# 3. Security Group
#########################
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "web-sg"
  }
}

#########################
# 4. Launch Template
#########################
resource "aws_launch_template" "example" {
  name_prefix   = "example-asg-"
  image_id      = var.ami_id
  instance_type = "t2.micro"

  network_interfaces {
    security_groups = [aws_security_group.web_sg.id]
  }

  user_data = base64encode("#!/bin/bash\nyum install -y httpd\nsystemctl start httpd\nsystemctl enable httpd\n")
}

#########################
# 5. Auto Scaling Group
#########################
resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]
  desired_capacity     = 2
  max_size            = 4
  min_size            = 1
  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "example-asg-instance"
    propagate_at_launch = true
  }
}

#########################
# 6. Variables for Flexibility
#########################
variable "region" {
  default = "us-east-1"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  default     = "ami-0c94855ba95c71c99" # Amazon Linux 2 (update as needed)
}