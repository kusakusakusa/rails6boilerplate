output "aws_key_pair" {
  value = aws_key_pair.main
}

output "assets-user-access_key_id" {
  value = module.assets-iam_user.this_iam_access_key_id
}

output "assets-user-secret_access_key" {
  value = module.assets-iam_user.this_iam_access_key_secret
}

output "assets-bucket_name" {
  value = aws_s3_bucket.assets.id
}

output "cloudwatch-user-access_key_id" {
  value = module.cloudwatch-iam_user.this_iam_access_key_id
}

output "cloudwatch-user-secret_access_key" {
  value = module.cloudwatch-iam_user.this_iam_access_key_secret
}
