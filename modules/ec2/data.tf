########################################
# Data Sources
########################################

# Get current AWS region
data "aws_region" "current" {}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# VPC - Use default VPC or specify VPC name
data "aws_vpc" "selected" {
  default = var.use_default_vpc

  dynamic "filter" {
    for_each = var.use_default_vpc ? [] : [1]
    content {
      name   = "tag:Name"
      values = [var.vpc_name]
    }
  }
}

# Public Subnet A - First subnet for ALB and EC2
data "aws_subnet" "public_subnet" {
  vpc_id = data.aws_vpc.selected.id

  filter {
    name   = "tag:Name"
    values = [var.subnet_name]
  }
}

# Public Subnet B - Second subnet for ALB (required for multi-AZ)
data "aws_subnet" "public_subnet_b" {
  vpc_id = data.aws_vpc.selected.id

  filter {
    name   = "tag:Name"
    values = [var.subnet_name_b]
  }
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ecr_repository" "sms_seller_connect" {
  name = "sms-wholesaling-backend"
}
