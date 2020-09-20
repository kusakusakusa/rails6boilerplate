variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "aws_subnet" {
  type = object({
    id = string
  })
}

variable "aws_security_group" {
  type = object({
    id = string
  })
}

variable "aws_key_pair" {
  type = object({
    key_name = string
  })
}
