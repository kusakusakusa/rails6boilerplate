resource "aws_db_instance" "main" {
  allocated_storage = 20
  storage_type = "gp2"
  engine = "mysql"
  engine_version = "5.7"
  instance_class = "db.t2.micro"
  identifier = "rds-${var.project_name}${var.env}"
  name = var.db_name
  username = var.db_username
  password = var.db_password
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot = false
  final_snapshot_identifier = "rds-${var.project_name}${var.env}-${formatdate("DD-MMM-YY", timestamp())}"

  lifecycle {
    prevent_destroy = false
  }
  backup_window = "15:00-15:30"
  backup_retention_period = 30
  delete_automated_backups = false
  db_subnet_group_name = aws_db_subnet_group.main.id

  tags = {
    Name = "rds-${var.project_name}${var.env}"
  }
}

resource "aws_security_group" "rds" {
  name = "rds-${var.project_name}${var.env}"
  description = "For RDS ${var.env}"

  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}${var.env}"
  }
}

resource "aws_security_group_rule" "mysql-rds-web_server" {
  type = "ingress"
  from_port = 3306
  to_port = 3306
  protocol = "tcp"
  security_group_id = aws_security_group.rds.id
  source_security_group_id = aws_security_group.web_server.id
}

resource "aws_security_group_rule" "mysql-rds-bastion" {
  type = "ingress"
  from_port = 3306
  to_port = 3306
  protocol = "tcp"
  security_group_id = aws_security_group.rds.id
  source_security_group_id = aws_security_group.bastion.id
}

locals {
  rds_database_url = "mysql2://${var.db_username}:${var.db_password}@${aws_db_instance.main.endpoint}/${var.db_name}"
}

resource "aws_db_subnet_group" "main" {
  name = "db-private-subnets"
  subnet_ids = [
aws_subnet.private-1.id,
aws_subnet.private-2.id,
  ]

  tags = {
    Name = "subnet-group-${var.project_name}${var.env}"
  }
}
