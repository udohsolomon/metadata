variable "region" {
  description = "The region to place all of the resources into"
  default     = "eu-west-1"
  type        = string
}

variable "profile" {
  description = "The AWS account profile to use to deploy the resources"
  default = "Account_two"
  type    = string
}

variable "shared_credentials_file"{
  description = "AWS access credentials"
  default = "~/.aws/credentials"
  type = string
}
variable "aws_account_id"{
  type = string
}
variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list
}

variable "private_subnets" {
  type = list
}

