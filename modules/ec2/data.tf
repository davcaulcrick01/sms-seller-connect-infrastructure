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

# Get all public subnets for ALB (need at least 2 in different AZs)
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
  
  # Filter for public subnets (those with internet gateway route)
  filter {
    name   = "route-table-association.route-table.route.gateway-id"
    values = ["igw-*"]
  }
}

# Primary subnet for EC2 instance
data "aws_subnet" "public_subnet" {
  id = data.aws_subnets.public.ids[0]
}

# Secondary subnet for ALB (different AZ)
data "aws_subnet" "public_subnet_b" {
  id = length(data.aws_subnets.public.ids) > 1 ? data.aws_subnets.public.ids[1] : data.aws_subnets.public.ids[0]
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ecr_repository" "sms_seller_connect" {
  name = "sms-wholesaling-backend"
}
