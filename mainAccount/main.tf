terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

   backend "s3" {
    bucket = "terrafrom-state-aws-s3"
    key = "main/terraform.tfstate"
    region = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt = true
    profile = "Account_one"
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
  shared_credentials_file = var.shared_credentials_file
}

#S3 bucket to store the terraform state
resource "aws_s3_bucket" "terrafrom-state-aws-s3" {
    bucket = "terrafrom-state-aws-s3"
    
    lifecycle {
        prevent_destroy = true
    }

    versioning {
        enabled = true
    }

    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default {
                sse_algorithm = "AES256"
            }
        }
    }
}

#AWS dynamo table to lock state
resource "aws_dynamodb_table" "terraform-locks" {
    name         = "terraform-locks"
    hash_key     = "LockID"
    billing_mode = "PAY_PER_REQUEST"
    attribute {
        name = "LockID"
        type = "S"
    }
    
  tags = {
    Name = "DynamoDB State Lock Table"
  }
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vpc main"
  cidr = var.vpc_cidr

  azs  = var.azs
  private_subnets = var.private_subnets

  enable_nat_gateway = false
  enable_vpn_gateway = false
  

  tags = {
    Terraform   = "true"
    Environment = terraform.workspace
  }
}

# Create a VPC Endpoint, this enabled AWS services to communicate to resources within our VPC without having to traverse the public internet.
# The main reason for creation here, is that Session Manager usually requires an instance to have a public IP address for management, we do not want
# our private subnet instances to have this (they inherently cannot, because they're in a private subnet), so we must use VPC endpoints instead.
# This keeps all communication internal to the AWS network.
module "vpc_vpc-endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "3.4.0"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [aws_security_group.ec2-instance-sg.id]

  endpoints = {
    ssm = {
      service             = "ssm"
      subnet_ids          = module.vpc.private_subnets
    },
    ssmmessages = {
      service             = "ssmmessages"
      subnet_ids          = module.vpc.private_subnets
    },
    ec2messages = {
      service             = "ec2messages"
      subnet_ids          = module.vpc.private_subnets
    }
  }
}


#USERS
resource "aws_iam_user" "ec2_user"{
  name = "ec2_user"
  path = "/users/"
}

resource "aws_iam_user_group_membership" "ec2_user_share_s3"{
  user = aws_iam_user.ec2_user.name
  groups = [
    aws_iam_group.share_s3.name
  ]
}

#GROUP
resource "aws_iam_group" "share_s3"{
  name ="share_s3"
  path = "/" 
}

resource "aws_iam_group_policy_attachment" "assume_share_s3_role"{
  count = length(aws_iam_policy.assume_env_share_s3_role)
  group = aws_iam_group.share_s3.name
  policy_arn = element(aws_iam_policy.assume_env_share_s3_role.*.arn,count.index)
}

resource "aws_iam_policy" "assume_env_share_s3_role" {
  count       = length(var.aws_account_ids)
  name        = "assume_${element(keys(var.aws_account_ids), count.index)}_env_share_s3_role"
  path        = "/"
  description = "Allows assuming the share_s3_role role in the ${element(keys(var.aws_account_ids), count.index)} environment"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::${lookup(var.aws_account_ids, element(keys(var.aws_account_ids), count.index))}:role/share_s3"
    }
  ]
}
EOF
}


resource "aws_instance" "ec2_instance" {
  ami           = "ami-00ae935ce6c2aa534"
  instance_type = "t2.micro"
  subnet_id    = "subnet-0b3aed00777ff82bb"
  security_groups = [aws_security_group.ec2-instance-sg.id]
  tags = {
    Name = "ec2-instance"
  }
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ssm.name
}

resource "aws_iam_role" "ssm" {
  name =  "ec2-instance-ssm"

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"] # AWS managed policy for Systems Manager
  assume_role_policy  = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow"
        }
    ]
}
EOF
}



# Security group definition for the EC2
resource "aws_security_group" "ec2-instance-sg" {
  name        = "ec2-instance-sg"
  description = "SG for the instance in the private subnets"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow inbound HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block] # Allow inbound traffic from our VPC, this is mainly used for SSM connections
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Environment = var.environment
  }

}

