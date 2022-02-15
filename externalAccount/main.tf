terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
  shared_credentials_file = var.shared_credentials_file
}

resource "aws_s3_bucket" "data"{
  bucket = "bucket-share_s3"
  acl    = "private"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vpc ${terraform.workspace}"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = terraform.workspace
  }
}

resource "aws_iam_role" "share_s3" {
  name = "share_s3"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::166340841143:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {}
    }
  ]
}
EOF
}

#S3 Full access Policy
resource "aws_iam_policy" "s3_full" {
  name        = "s3_full_access"
  path        = "/"
  description = "S3 Full access policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.data.arn}",
        "${aws_s3_bucket.data.arn}/*"
      ]
        
    }
  ]
}
EOF
}

# Dev permissions
resource "aws_iam_role_policy_attachment" "share_s3_full" {
  count      = terraform.workspace == "s3_user" ? 1 : 0
  role       = aws_iam_role.share_s3.name
  policy_arn = aws_iam_policy.s3_full.arn
}

