module "cloudwatch-iam_user" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "~> 2.0"

  create_iam_access_key = "true"
  create_iam_user_login_profile = "false"

  name = "cloudwatch-${var.project_name}${var.env}"

  tags = {
    Name = "cloudwatch-${var.project_name}${var.env}"
  }
}

resource "aws_iam_user_policy_attachment" "cloudwatch" {
  user = module.cloudwatch-iam_user.this_iam_user_name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

output "cloudwatch-user-access_key_id" {
  value = module.cloudwatch-iam_user.this_iam_access_key_id
}

output "cloudwatch-user-secret_access_key" {
  value = module.cloudwatch-iam_user.this_iam_access_key_secret
}
