########################################
# SMS Seller Connect EC2 Module
########################################

# This module creates SMS Seller Connect infrastructure with ALB multi-app architecture
# 
# Resources are organized in their respective files:
# - terraform.tf: Terraform and provider configuration
# - data.tf: Data sources for AWS resources
# - ec2.tf: EC2 instances, key pairs, elastic IPs
# - s3.tf: S3 buckets and S3 objects
# - iam.tf: IAM roles, policies, and instance profiles  
# - alb.tf: Application Load Balancer resources
# - sg.tf: Security Groups
# - route53.tf: DNS records
# - acm.tf: SSL certificates
# - cloudwatch.tf: CloudWatch logs and monitoring
# - variables.tf: Input variables
# - outputs.tf: Output values
# - locals.tf: Local values


terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "greyzone-terraform-state"
    key            = "sms-seller-connect/ec2/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project      = "SMSSellerConnect"
      Environment  = var.environment
      ManagedBy    = "Terraform"
      Owner        = "GreyZone"
      Architecture = "ALB-MultiApp"
      Module       = "EC2"
    }
  }
}
