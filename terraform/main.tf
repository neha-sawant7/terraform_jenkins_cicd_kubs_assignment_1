
# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 6.0"
#     }
#   }
# }

# provider "aws" {
#     region = "us-east-2"
# }

# resource "tls_private_key" "rsa_4096" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# variable "key_name" {}

# resource "aws_key_pair" "key_pair" {
#   key_name   = var.key_name
#   public_key = tls_private_key.rsa_4096.public_key_openssh
# }

# resource "local_file" "private_key"{
#     content = tls_private_key.rsa_4096.private_key_pem
#     filename =var.key_name
# }

# resource "aws_instance" "public_instance" {
#   ami           = "ami-0cfde0ea8edd312d4"
#   instance_type = "t2.micro"
#   key_name = aws_key_pair.key_pair.key_name

#   tags = {
#     Name = "public_instance"
#   }
# }
#keyname: tera_key


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.0"
}

############################
# Variables (edit defaults)
############################
variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "key_name" {
  type    = string
  default = "my_tf_key"
}

variable "ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "jenkins_instance_type" {
  type    = string
  default = "t3.small"
}

variable "k3s_instance_type" {
  type    = string
  default = "t3.small"
}

variable "public_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "ami" {
  type    = string
  default = "ami-0cfde0ea8edd312d4"
}

############################
# Provider
############################
provider "aws" {
  region = var.aws_region
}

############################
# Key pair
############################
resource "tls_private_key" "rsa_4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.rsa_4096.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.rsa_4096.private_key_pem
  filename = "${path.module}/${var.key_name}.pem"
}

############################
# Security Group
############################
resource "aws_security_group" "common_sg" {
  name        = "jenkins-k3s-sg"
  description = "Allow SSH, Jenkins, HTTP, k8s API"

  ingress {
    description    = "SSH"
    from_port      = 22
    to_port        = 22
    protocol       = "tcp"
    cidr_blocks    = [var.ssh_cidr]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }

  ingress {
    description    = "Jenkins UI"
    from_port      = 8080
    to_port        = 8080
    protocol       = "tcp"
    cidr_blocks    = [var.ssh_cidr]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }

  ingress {
    description    = "HTTP"
    from_port      = 80
    to_port        = 80
    protocol       = "tcp"
    cidr_blocks    = [var.ssh_cidr]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }

  ingress {
    description    = "k3s API"
    from_port      = 6443
    to_port        = 6443
    protocol       = "tcp"
    cidr_blocks    = [var.ssh_cidr]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }

  egress {
    description     = "all outbound"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }
}



############################
# ECR repository
############################
resource "aws_ecr_repository" "app_repo" {
  name = "myapp"
}

############################
# IAM role and policy for Jenkins EC2 (ECR access)
############################
data "aws_iam_policy_document" "jenkins_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "jenkins_role" {
  name               = "jenkins-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume.json
}

resource "aws_iam_policy" "jenkins_policy" {
  name = "jenkins-ecr-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:CreateRepository",
          "ecr:DescribeRepositories",
          "ecr:GetRepositoryPolicy",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_attach" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = aws_iam_policy.jenkins_policy.arn
}

resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkins-instance-profile"
  role = aws_iam_role.jenkins_role.name
}

############################
# Original public_instance (kept from your code)
############################
resource "aws_instance" "public_instance" {
  ami                    = var.ami
  instance_type          = var.public_instance_type
  key_name               = aws_key_pair.key_pair.key_name
  vpc_security_group_ids = [aws_security_group.common_sg.id]

  tags = {
    Name = "public_instance"
  }
}

############################
# Jenkins EC2
############################
resource "aws_instance" "jenkins" {
  ami                    = var.ami
  instance_type          = var.jenkins_instance_type
  key_name               = aws_key_pair.key_pair.key_name
  iam_instance_profile   = aws_iam_instance_profile.jenkins_profile.name
  vpc_security_group_ids = [aws_security_group.common_sg.id]

  tags = {
    Name = "jenkins"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -ex
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-11-jdk apt-transport-https ca-certificates curl gnupg lsb-release git docker.io unzip jq
    systemctl enable --now docker
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y jenkins
    usermod -aG docker jenkins || true
    systemctl enable --now jenkins
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    apt-get install -y unzip
    unzip /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install || true
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl || true
  EOF
}

############################
# k3s single-node EC2
############################
resource "aws_instance" "k3s" {
  ami                    = var.ami
  instance_type          = var.k3s_instance_type
  key_name               = aws_key_pair.key_pair.key_name
  vpc_security_group_ids = [aws_security_group.common_sg.id]

  tags = {
    Name = "k3s"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -ex
    apt-get update
    apt-get install -y curl
    curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -
    if id -u ubuntu >/dev/null 2>&1; then
      mkdir -p /home/ubuntu/.kube
      cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config || true
      chown -R ubuntu:ubuntu /home/ubuntu/.kube || true
    fi
  EOF
}

############################
# Outputs
############################
output "private_key_path" {
  value       = local_file.private_key.filename
  description = "Path to the generated private key to SSH into instances."
}

output "jenkins_public_ip" {
  value       = aws_instance.jenkins.public_ip
  description = "Public IP of Jenkins instance"
}

output "k3s_public_ip" {
  value       = aws_instance.k3s.public_ip
  description = "Public IP of k3s instance"
}

output "public_instance_ip" {
  value       = aws_instance.public_instance.public_ip
  description = "Public IP of original instance"
}

output "ecr_repo_url" {
  value       = aws_ecr_repository.app_repo.repository_url
  description = "ECR repository URL"
}
