resource "aws_key_pair" "main" {
  key_name = "${var.project_name}-${var.env}"
  public_key = var.public_key
}
