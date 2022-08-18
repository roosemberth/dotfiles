terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 0.5"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "eu-west-3"
}

module "nixos_image" {
  source          = "github.com/tweag/terraform-nixos//deploy_nixos?ref=646cacb12439ca477c05315a7bfd49e9832bc4e3"
  target_system   = "aarch64-linux"
  target_host     = aws_instance.strong_ghost.public_ip
  build_on_target = true
  # Wrapped in nonsensitive because I want to see logs...
  ssh_private_key = nonsensitive(data.sops_file.tf.data["ssh-keys.deploy-strong-ghost"])
  # Need to force-disable because 'nonsensitive' breaks the default value...
  ssh_agent = false

  nixos_config = "strong-ghost"
  flake        = true
  hermetic     = true

  keys = {
    ssh_host     = data.sops_file.tf.data["hosts.strong-ghost.ssh-host-ed25519"]
    ssh_host_pub = data.sops_file.tf.data["hosts.strong-ghost.ssh-host-ed25519.pub"]
  }
}

module "key_pair" {
  source     = "terraform-aws-modules/key-pair/aws"
  key_name   = "deploy-strong-ghost"
  public_key = data.sops_file.tf.data["ssh-keys.deploy-strong-ghost.pub"]
}

resource "aws_security_group" "ssh_and_egress" {
  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_instance" "strong_ghost" {
  ami             = "ami-0c0ebe20ebfc635a1" # "22.05".eu-west-3.aarch64-linux.hvm-ebs
  instance_type   = "t4g.small"
  security_groups = [aws_security_group.ssh_and_egress.name]
  key_name        = "deploy-strong-ghost"

  root_block_device {
    volume_size           = 30 # GiB
    delete_on_termination = true
  }
}

data "sops_file" "tf" {
  source_file = "secrets/tf.yaml"
}

output "public_dns" {
  value = aws_instance.strong_ghost.public_dns
}
