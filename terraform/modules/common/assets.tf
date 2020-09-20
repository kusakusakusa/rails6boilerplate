resource "aws_s3_bucket" "assets" {
  bucket = "${var.project_name}-${var.env}-assets"
  region = "ap-southeast-1"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
  }

  tags = {
    Name = var.project_name
    Env = var.env
  }
}

module "assets-iam_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 2.0"

  name = "assets-policy-${var.project_name}${var.env}"
  description = "Assets bucket policy for ${var.project_name}-${var.env}"

  policy = templatefile("${path.module}/assets_bucket_policy.tmpl", { bucket_name = aws_s3_bucket.assets.id })
}

module "assets-iam_user" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "~> 2.0"

  create_iam_access_key = "true"
  create_iam_user_login_profile = "false"

  name = "assets-${var.project_name}${var.env}"

  tags = {
    Name = "assets-${var.project_name}${var.env}"
  }
}

resource "aws_iam_user_policy_attachment" "assets" {
  user = module.assets-iam_user.this_iam_user_name
  policy_arn = module.assets-iam_policy.arn
}
