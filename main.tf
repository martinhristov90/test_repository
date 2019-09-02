# Create a new instance of the latest Ubuntu 14.04 on an
# t2.micro node with an AWS Tag naming it "HelloWorld"
provider "aws" {
  region = "us-east-1"
}

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

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  user_data     = data.template_cloudinit_config.myhost.rendered

  key_name = "marti"
  tags = {
    Name = "HelloWorld"
  }
}

locals {
  algorithms = ["RSA", "ECDSA"]
}

resource "tls_private_key" "host" {
  count       = length(local.algorithms)
  algorithm   = local.algorithms[count.index]
  ecdsa_curve = local.algorithms[count.index] == "ECDSA" ? "P384" : ""
  rsa_bits    = local.algorithms[count.index] == "RSA" ? 4096 : 2048
}

output "ssh_public_keys" {
  value = tls_private_key.host[*].public_key_openssh
}

data "template_cloudinit_config" "myhost" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = file("${path.module}/cloud-config.yml")
  }

  part {
    content_type = "text_cloud-config"
    content = templatefile("${path.module}/cloud-config-ssh-keys.yml.tmpl", {
      keys = [
        for k in tls_private_key.host[*] : {
          private   = indent(4, chomp(k.private_key_pem))
          public    = chomp(k.public_key_openssh)
          algorithm = lower(k.algorithm)
        }
      ]
    })
  }
}

