module "secrets_bucket" {
  source = "trussworks/s3-private-bucket/aws"
  version = "~> 1.7.2"
  bucket = "${var.project_name}-${var.env}-secrets"
  logging_bucket = module.aws_logs.aws_logs_bucket
  use_account_alias_prefix = "false"

  tags = {
    Name = var.project_name
    Env = var.env
  }
}

resource "aws_s3_bucket_object" "private_key" {
  bucket = module.secrets_bucket.id
  key = "${var.project_name}-${var.env}"
  source = "ssh_keys/${var.project_name}-${var.env}"

  tags = {
    Name = var.project_name
    Env = var.env
  }
}

resource "aws_s3_bucket_object" "public_key" {
  bucket = module.secrets_bucket.id
  key = "${var.project_name}-${var.env}.pub"
  source = "ssh_keys/${var.project_name}-${var.env}.pub"

  tags = {
    Name = var.project_name
    Env = var.env
  }
}

# copy master.key to s3 for storage purpose
resource "aws_s3_bucket_object" "master_key" {
  bucket = module.secrets_bucket.id
  key = "master.key"
  source = "master.key"

  tags = {
    Name = var.project_name
    Env = var.env
  }
}

# with reference to https://stackoverflow.com/a/52868251/2667545

data "aws_iam_policy_document" "secrets_bucket" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "secrets_bucket" {
  name = "${var.project_name}-${var.env}-secrets_bucket"
  description = "Allow reading from the S3 bucket"

  policy = templatefile("${path.module}/secrets_bucket_iam_policy.tmpl", { bucket_arn = module.secrets_bucket.arn })
}

resource "aws_iam_role" "secrets_bucket" {
  name = "${var.project_name}-${var.env}-secrets_bucket"
  assume_role_policy = data.aws_iam_policy_document.secrets_bucket.json
}

resource "aws_iam_role_policy_attachment" "secrets_bucket" {
  role = aws_iam_role.secrets_bucket.name
  policy_arn = aws_iam_policy.secrets_bucket.arn
}

resource "aws_iam_instance_profile" "secrets_bucket" {
  name = "${var.project_name}-${var.env}-secrets_bucket"
  role = aws_iam_role.secrets_bucket.name
}
