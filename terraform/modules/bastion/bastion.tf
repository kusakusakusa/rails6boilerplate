data "aws_ami" "bastion" {
  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "tag:Name"
    values = ["bastion-${var.project_name}-${var.env}"]
  }

  most_recent = true
  owners = ["self"]
}

resource "aws_instance" "bastion" {
  ami = data.aws_ami.bastion.id
  associate_public_ip_address = true
  instance_type = "t2.nano"
  subnet_id = var.aws_subnet.id
  vpc_security_group_ids = [var.aws_security_group.id]
  key_name = var.aws_key_pair.key_name

  tags = {
    Name = "bastion-${var.project_name}-${var.env}"
  }
}
