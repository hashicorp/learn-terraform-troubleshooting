terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.24.1"
    }
  }
  required_version = "~> 0.14"
}

variable "region" {
  description = "The AWS region your resources will be deployed"
}

variable "name" {
  description = "The operator name running this configuration"
}

provider "aws" {
  region = var.region
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_instance" "example" {
  for_each               = aws_security_group.*.id
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [each.id]
  user_data              = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
 tags = {
    Name = $var.name-learn
  }
}

resource "aws_security_group" "sg_ping" {
  name = "Allow Ping"

  ingress {
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.sg_8080.id]
  }
}

resource "aws_security_group" "sg_8080" {
  name = "Allow 8080"

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ping.id]
  }
}

resource "aws_security_group_rule" "allow_localhost_8080" {
type = "ingress"
  from_port = 8080
  to_port = 8080                            
  protocol = "tcp"
  cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  security_group_id = aws_security_group.sg_8080.id
}

resource "aws_security_group_rule" "allow_localhost_ping" {
type = "ingress"
  from_port = -1
  to_port = -1
  protocol = "icmp"
  cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  security_group_id = aws_security_group.sg_ping.id
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.example.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.example.public_ip
}

output "instance_name" {
  description = "Tags of the EC2 instance"
  value       = aws_instance.example.tags
}
