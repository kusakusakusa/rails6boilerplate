resource "aws_key_pair" "this" {
  key_name = var.project_name
  public_key = file("${path.module}/ssh_keys/${var.project_name}-${var.env}.pub")
}

resource "aws_security_group" "this" {
  name = var.project_name
  description = "Security group for ${var.project_name}-${var.env} project"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = var.project_name
    Env = var.env
  }
}

resource "aws_eip" "this" {
  vpc = true
  tags = {
    Name = var.project_name
    Env = var.env
  }

  # lifecycle {
  #   prevent_destroy = true
  # }
}

resource "aws_eip_association" "this" {
  instance_id   = "${aws_instance.this.id}"
  allocation_id = "${aws_eip.this.id}"
}

resource "aws_instance" "this" {
  ami = "ami-03b6f27628a4569c8" # ubuntu 18.04 LTS
  instance_type = "t2.micro" # need at least micro or have problem installing nokogiri
  availability_zone = "${var.region}a"
  key_name = aws_key_pair.this.key_name
  security_groups = [
    aws_security_group.this.name
  ]

  iam_instance_profile = aws_iam_instance_profile.secrets_bucket.name

  tags = {
    Name = var.project_name
    Env = var.env
  }
}
