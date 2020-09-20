resource "aws_db_instance" "main" {
  allocated_storage = 20
  storage_type = "gp2"
  engine = "mysql"
  engine_version = "5.7"
  instance_class = "db.t3.micro"
  identifier = "rds-${var.project_name}${var.env}"
  name = var.db_name
  username = var.db_username
  password = var.db_password
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot = true
  publicly_accessible = true

  tags = {
    Name = "rds-${var.project_name}${var.env}"
  }
}

resource "aws_security_group" "rds" {
    name = "rds-${var.project_name}${var.env}"
    description = "For RDS ${var.env}"

  tags = {
    Name = "${var.project_name}${var.env}"
  }
}

resource "aws_security_group" "web_server-single_instance" {
  name = "web_server-single_instance-${var.project_name}${var.env}"
  description = "For web servers ${var.env}"

  tags = {
    Name = "${var.project_name}${var.env}"
  }
}

resource "aws_security_group_rule" "mysql-rds-web_server-single_instance" {
  type = "ingress"
  from_port = 3306
  to_port = 3306
  protocol = "tcp"
  security_group_id = aws_security_group.rds.id
  source_security_group_id = aws_security_group.web_server-single_instance.id
}

resource "aws_security_group_rule" "ssh-world-web_server-single_instance" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  security_group_id = aws_security_group.web_server-single_instance.id
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "mysql-world-rds" {
  type = "ingress"
  from_port = 3306
  to_port = 3306
  protocol = "tcp"
  security_group_id = aws_security_group.rds.id
  cidr_blocks = ["0.0.0.0/0"]
}

locals {
  rds_database_url = "mysql2://${var.db_username}:${var.db_password}@${aws_db_instance.main.endpoint}/${var.db_name}"
}
