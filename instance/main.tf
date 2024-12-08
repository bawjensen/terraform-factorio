provider "aws" {
  region = var.region
}

locals {
  save_game_dir = "/opt/factorio/saves"
  # To load named save game: --start-server ${path}/${name}.zip
  # To load latest save game: --start-server-load-latest

  save_game_arg = (var.factorio_save_game != "" ?
    "-e LOAD_LATEST_SAVE=false -e SAVE_NAME='${local.save_game_dir}/${var.factorio_save_game}.zip'" :
  "")
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-*-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
}

resource "aws_key_pair" "key" {
  key_name   = var.name
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "aws_default_vpc" "default" {
}

resource "aws_security_group" "instance" {
  vpc_id = aws_default_vpc.default.id
  name   = "${var.name}-security-group"
  tags   = var.tags

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "udp"
    from_port   = 34197
    to_port     = 34197
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "factorio" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  tags                        = var.tags

  root_block_device {
    volume_size           = 8
    volume_type           = "gp2"
    delete_on_termination = true
  }

  iam_instance_profile = var.instance_profile

  key_name = aws_key_pair.key.key_name
  # Does setup like installing docker, restoring saved games from S3, and starting server
  user_data = templatefile("./instance-setup.sh", {
    save_game_arg    = local.save_game_arg
    factorio_version = var.factorio_version
  })
  security_groups = [aws_security_group.instance.name]

  provisioner "file" {
    source      = "conf"
    destination = "/tmp"
  }

  provisioner "file" {
    content = templatefile("./conf/server-settings.json", {
      server_password = var.server_password
    })
    destination = "/tmp/conf/server-settings.json"
  }

  provisioner "file" {
    source      = "./factorio-back-up-saves.sh"
    destination = "/tmp/factorio-back-up-saves.sh"
  }

  provisioner "file" {
    source      = "./factorio-restore-saves.sh"
    destination = "/tmp/factorio-restore-saves.sh"
  }

  connection {
    host        = self.public_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.ssh.private_key_pem
  }
}

resource "null_resource" "provision" {
  triggers = {
    instance_id = aws_instance.factorio.id
    instance_ip = aws_instance.factorio.public_ip
    private_key = tls_private_key.ssh.private_key_pem
  }

  # Stop headless server and backup save games to S3 on destroy.
  provisioner "remote-exec" {
    when = destroy
    inline = [
      "sudo docker stop factorio",
      "sudo factorio-back-up-saves.sh",
    ]
  }

  connection {
    host        = self.triggers.instance_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = self.triggers.private_key
  }
}
