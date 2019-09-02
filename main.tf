provider "aws" {
  region = "us-east-1"
}
# Getting latest AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}
# Test instance
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  # Rendering both yml files
  user_data     = data.template_cloudinit_config.myhost.rendered

  key_name = "marti"
  tags = {
    Name = "HelloWorld"
  }
}
# Two types of host keys alghorithms need to be used.
locals {
  algorithms = ["RSA", "ECDSA"]
}
# Those keys are going to be used as host keys.
resource "tls_private_key" "host" {
  count       = length(local.algorithms)
  algorithm   = local.algorithms[count.index]
  ecdsa_curve = local.algorithms[count.index] == "ECDSA" ? "P384" : ""
  rsa_bits    = local.algorithms[count.index] == "RSA" ? 4096 : 2048
}
# Just printing the public keys.
output "ssh_public_keys" {
  value = tls_private_key.host[*].public_key_openssh
}
# Generates tempalte that can be rendered as user_data
data "template_cloudinit_config" "myhost" {
  gzip          = true
  base64_encode = true
  # This part is for setting hostname and altering the default user
  part {
    content_type = "text/cloud-config"
    content      = file("${path.module}/cloud-config.yml")
  }
  # This part alters the host keys using template
  part {
    content_type = "text_cloud-config"
    content = templatefile("${path.module}/cloud-config-ssh-keys.yml.tmpl", {
      keys = [
        for k in tls_private_key.host[*] : {
          # adding four spaces in front of the all lines of the private key and trimming tailing newlines chars
          private   = indent(4, chomp(k.private_key_pem))
          # trimming tailing newlines chars
          public    = chomp(k.public_key_openssh)
          algorithm = lower(k.algorithm)
        }
      ]
    })
  }
}

