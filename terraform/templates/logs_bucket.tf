module "aws_logs" {
  source = "trussworks/logs/aws"
  s3_bucket_name = "${var.project_name}-${var.env}-logs"
  region = var.region
}
