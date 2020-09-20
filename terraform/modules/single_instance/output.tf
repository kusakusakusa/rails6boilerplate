output "endpoint_url" {
  value = aws_elastic_beanstalk_environment.main.endpoint_url
}

output "rds-database-url" {
  value = local.rds_database_url
}
