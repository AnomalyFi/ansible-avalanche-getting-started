terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "aws" {
  region = "us-east-2"
  profile = "PowerUserAccess-975050373654"
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "ansible_key"
  public_key = tls_private_key.pk.public_key_openssh

  provisioner "local-exec" {
    command = "echo '${tls_private_key.pk.private_key_pem}' > ../../files/ansible_key.pem && chmod 400 ../../files/ansible_key.pem"
  }
}

resource "aws_security_group" "ssh_eth_sg" {
  name = "ssh_eth"
  description = "Allow SSH, ETH RPC & WS and outbound traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ETH RPC"
    from_port   = 8545
    to_port     = 8545
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "ETH WS"
    from_port   = 8546
    to_port     = 8546
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssh_avax_sg" {
  name        = "ssh_avax"
  description = "Allow SSH, AVAX HTTP & Staking and outbound traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "AVAX HTTP"
    from_port   = 9650
    to_port     = 9650
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "AVAX Staking"
    from_port   = 9651
    to_port     = 9651
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_file" "user_data" {
  template = file("../../files/multipass/cloud-init.yaml")
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # images belongs to AWS
}

resource "aws_instance" "validators" {
  for_each = {
    for i in range(1, 6) : "validator0${i}" => i
  }

  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.kp.key_name
  user_data = data.template_file.user_data.rendered
  security_groups = [
    aws_security_group.ssh_avax_sg.name
  ]
  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = each.key
  }
}

data "aws_instance" "validators_info" {
  depends_on = [
    aws_instance.validators
  ]

  for_each = {
    for i in range(1, 6) : "validator0${i}" => i
  }

  instance_tags = {
    Name = each.key
  }

  filter {
    name = "instance-state-name"
    values = ["running"]
  }
}

resource "aws_instance" "frontend" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.small"
  key_name = aws_key_pair.kp.key_name
  user_data = data.template_file.user_data.rendered
  security_groups = [
    aws_security_group.ssh_eth_sg.name
  ]
  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = "ETH-L1"
  } 
}

data "aws_instance" "frontend_info" {
  depends_on = [
    aws_instance.frontend
  ]

  instance_tags = {
    Name = "ETH-L1"
  }

  filter {
    name = "instance-state-name"
    values = ["running"]
  }
}

# Ansible hosts templating
resource "local_file" "ansible_hosts" {
  content = templatefile(
    "hosts.tftpl",
    {
      validators = values(data.aws_instance.validators_info)
      frontend   = data.aws_instance.frontend_info
    }
  )
  filename = "hosts.ini"
}

# Outputs
output "validators_ips" {
  value = values(data.aws_instance.validators_info).*.public_ip
}

output "frontend_ip" {
  value = data.aws_instance.frontend_info.public_ip
}

# Docker
provider "docker" {}

# NGINX configuration templating
resource "local_file" "nginx_conf" {
  content  = templatefile(
    "nginx.tftpl",
    {
      validators = values(data.aws_instance.validators_info)
    }
  )
  filename = abspath("nginx.conf")
}

# NGINX Docker image
resource "docker_image" "nginx" {
  name         = "nginx:1.25.3"
  keep_locally = true
}

# NGINX Docker container
resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "avax_nginx"
  ports {
    internal = 80
    external = 80
  }
  mounts {
    target = "/etc/nginx/nginx.conf"
    type   = "bind"
    source = local_file.nginx_conf.filename
  }
}


# resource "aws_instance" "fuji_node" {
#   ami           = "ami-053b0d53c279acc90"
#   instance_type = "t2.2xlarge"
#   key_name      = aws_key_pair.kp.key_name
#   security_groups = [
#     aws_security_group.ssh_avax_sg.name
#   ]
#   root_block_device {
#     volume_size = 300
#   }
# }

# output "fuji_node_ip" {
#   value = aws_instance.fuji_node.public_ip
# }
