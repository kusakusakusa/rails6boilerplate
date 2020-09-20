resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16" # 65536 ip addresses

  tags = {
    Name = "${var.project_name}${var.env}"
  }
}

# IGW
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}${var.env}"
  }
}

resource "aws_route_table" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${var.project_name}${var.env}"
  }
}

resource "aws_route" "igw" {
  route_table_id = aws_route_table.igw.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.main.id
}

# NGW
resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.public-1.id

  tags = {
    Name = "${var.project_name}${var.env}"
  }
}

resource "aws_route_table" "ngw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ngw-${var.project_name}${var.env}"
  }
}

resource "aws_route" "ngw" {
  route_table_id = aws_route_table.ngw.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main.id
}

# Security Groups
resource "aws_security_group" "bastion" {
  name = "${var.project_name}${var.env}-bastion"
  description = "For bastion server ${var.env}"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}${var.env}"
  }
}

# allow ssh into bastion
resource "aws_security_group_rule" "ssh-bastion-world" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  # Please restrict your ingress to only necessary IPs and ports.
  # Opening to 0.0.0.0/0 can lead to security vulnerabilities
  # You may want to set a fixed ip address if you have a static ip
  security_group_id = aws_security_group.bastion.id
  cidr_blocks = ["0.0.0.0/0"]
}

# allow bastion to ssh into private instances
resource "aws_security_group_rule" "ssh-bastion-web_server" {
  type = "egress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  security_group_id = aws_security_group.bastion.id
  source_security_group_id = aws_security_group.web_server.id
}

# allow bastion to connect out into rds
resource "aws_security_group_rule" "mysql-bastion-rds" {
  type = "egress"
  from_port = 3306
  to_port = 3306
  protocol = "tcp"
  security_group_id = aws_security_group.bastion.id
  source_security_group_id = aws_security_group.rds.id
}

resource "aws_security_group" "web_server" {
  name = "${var.project_name}${var.env}-web-servers"
  description = "For Web servers ${var.env}"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}${var.env}"
  }
}

# allow bastion to ssh into private instances
# rule will be duplicated with elastic beanstalk default security groups
resource "aws_security_group_rule" "ssh-web_server-bastion" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  security_group_id = aws_security_group.web_server.id
  source_security_group_id = aws_security_group.bastion.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

# only make 2 subnets, as the all regions have at least 2 AZ
resource "aws_subnet" "public-1" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.100.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "public-1-${var.project_name}${var.env}"
  }
}

resource "aws_subnet" "public-2" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.101.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "public-2-${var.project_name}${var.env}"
  }
}

resource "aws_subnet" "private-1" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_subnet" "private-2" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
}

resource "aws_route_table_association" "public-1" {
  subnet_id = aws_subnet.public-1.id
  route_table_id = aws_route_table.igw.id
}

resource "aws_route_table_association" "public-2" {
  subnet_id = aws_subnet.public-2.id
  route_table_id = aws_route_table.igw.id
}

resource "aws_route_table_association" "private-1" {
  subnet_id = aws_subnet.private-1.id
  route_table_id = aws_route_table.ngw.id
}

resource "aws_route_table_association" "private-2" {
  subnet_id = aws_subnet.private-2.id
  route_table_id = aws_route_table.ngw.id
}
