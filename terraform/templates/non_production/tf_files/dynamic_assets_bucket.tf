resource "aws_s3_bucket" "dynamic_assets" {
  bucket = "${var.project_name}-${var.env}-dynamic-assets"

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

resource "aws_s3_bucket_policy" "dynamic_assets" {
  bucket = aws_s3_bucket.dynamic_assets.id

  policy = templatefile("${path.module}/public_bucket.tmpl", { bucket_arn = aws_s3_bucket.dynamic_assets.arn })
}
