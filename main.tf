terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "app_sg" {
  name        = "sijil-backend-sg"
  description = "Security group for Sijil backend"
  vpc_id      = null # default VPC

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "App port"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  env_lines = [for k, v in var.backend_env : "${k}=${v}"]
  env_file  = join("\n", local.env_lines)
}

data "template_cloudinit_config" "init" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOT
      #!/bin/bash
      set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive

      apt-get update -y
      apt-get install -y curl git ufw

      # NodeJS LTS
      curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
      apt-get install -y nodejs
      npm install -g pm2

      # App directory
      mkdir -p /opt/sijil
      cd /opt/sijil

      # Clone repo
      if [ ! -d /opt/sijil/app ]; then
        git clone --depth=1 --branch ${var.app_repo_branch} ${var.app_repo_url} app
      fi

      cd app/backend

      # Write .env from TF vars
      cat > .env <<'EOF'
${local.env_file}
EOF

      npm ci || npm install

      # UFW
      ufw allow OpenSSH
      ufw allow ${var.app_port}/tcp
      ufw --force enable

      # Start app
      pm2 start server.js --name sijil-backend --update-env
      pm2 save
      pm2 startup systemd -u ubuntu --hp /home/ubuntu | sed -n 's/^.*sudo //p' | bash || true
    EOT
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  user_data_base64       = data.template_cloudinit_config.init.rendered

  # Prevent accidental replacement
  lifecycle {
    ignore_changes = [
      ami,  # Allow AMI updates without replacing instance
    ]
    create_before_destroy = false
  }

  tags = {
    Name = "sijil-backend"
  }
}

resource "aws_eip" "app_eip" {
  count      = var.allocate_eip ? 1 : 0
  instance   = aws_instance.app.id
  domain     = "vpc"
}

output "public_ip" {
  value = coalesce(try(aws_eip.app_eip[0].public_ip, null), aws_instance.app.public_ip)
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${coalesce(try(aws_eip.app_eip[0].public_ip, null), aws_instance.app.public_ip)}"
}

