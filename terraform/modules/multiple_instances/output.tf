output "endpoint_url" {
  value = aws_elastic_beanstalk_environment.main.endpoint_url
}

output "rds-database-url" {
  value = local.rds_database_url
}

output "aws_subnet" {
  value = aws_subnet.public-1
}

output "aws_security_group" {
  value = aws_security_group.bastion
}