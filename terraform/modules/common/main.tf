provider "aws" {
  version = "~> 2.24"
  region = var.region
}

terraform {
  required_version = "~> 0.13.0"
  backend "s3" {
    bucket = "${var.project_name}-${var.env}-tfstate"
    key = "terraform.tfstate"
    region = var.region
  }
}

provider "null" {
  version = "~> 2.1"
}