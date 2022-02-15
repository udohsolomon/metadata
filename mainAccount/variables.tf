variable "region" {
  description = "The region to place all of the resources into"
  default     = "eu-west-1"
  type        = string
}

variable "environment" {
  description = "The environment that is being deployed into"
  default     = "dev"
  type        = string
}

variable "profile" {
  description = "The AWS account profile to use to deploy the resources"
  default = "Account_one"
  type    = string
}

variable "shared_credentials_file"{
  description = "AWS access credentials"
  default = "~/.aws/credentials"
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "aws_account_ids" {
  type = map
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

