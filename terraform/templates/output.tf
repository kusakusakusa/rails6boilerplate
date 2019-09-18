output "eip" {
  value = aws_eip.this.public_ip
}

output "secrets_bucket" {
  value = module.secrets_bucket.id
}

output "logs_bucket" {
  value = module.aws_logs.aws_logs_bucket
}
