variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "aws_key_pair" {
  type = object({
    id = string
  })
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}

variable "db_name" {
  type = string
}

variable "master_key" {
  type = string
}

variable "ssl_arn" {
  type = string
  default = ""
}
