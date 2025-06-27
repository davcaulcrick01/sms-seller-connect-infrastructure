# AWS Region
variable "region" {
  description = "AWS region"
  type        = string
}

# EC2 Instance AMI ID
variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

# EC2 Instance Type
variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
}

# EC2 Instance Key Name
variable "key_name" {
  description = "Key name for the EC2 instance"
  type        = string
}

# EC2 Instance Name
variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
}

# VPC and Subnet Details
variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "subnet_name" {
  description = "Name of the first public subnet"
  type        = string
}

variable "subnet_name_b" {
  description = "Name of the second public subnet (required for ALB)"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the EC2 instance"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}

# S3 Bucket Configuration
variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "s3_acl" {
  description = "ACL for the S3 bucket"
  type        = string
}

variable "s3_force_destroy" {
  description = "Force destroy the S3 bucket (true for non-empty buckets)"
  type        = bool
}

# Common Tags
variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}

variable "ecr_repo_url" {
  description = "ECR repository URL"
  type        = string
}

variable "container_tag" {
  description = "Tag of the container image to pull"
  type        = string
}

variable "app_port" {
  description = "Port for the application"
  type        = string
}

# Route53 and ALB Configuration
variable "route53_zone_id" {
  description = "ID of the Route53 hosted zone"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  type        = string
}

variable "alb_zone_id" {
  description = "Canonical hosted zone ID of the Application Load Balancer"
  type        = string
}

# CloudWatch Monitoring Configuration
variable "alert_email" {
  description = "Email address for CloudWatch alerts and notifications"
  type        = string
}

########################################
# SMS Seller Connect Application Variables
########################################

# Docker Image Configuration
variable "backend_image" {
  description = "Docker image for SMS backend (ECR repository URL with tag)"
  type        = string
}

variable "frontend_image" {
  description = "Docker image for SMS frontend (ECR repository URL with tag)"
  type        = string
}

# Database Configuration
variable "db_host" {
  description = "Database host"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Database port"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_user" {
  description = "Database user"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# Twilio Configuration
variable "twilio_account_sid" {
  description = "Twilio Account SID"
  type        = string
  sensitive   = true
}

variable "twilio_auth_token" {
  description = "Twilio Auth Token"
  type        = string
  sensitive   = true
}

variable "twilio_phone_number" {
  description = "Twilio Phone Number"
  type        = string
  sensitive   = true
}

# OpenAI Configuration
variable "openai_api_key" {
  description = "OpenAI API Key"
  type        = string
  sensitive   = true
}

variable "openai_model" {
  description = "OpenAI model to use"
  type        = string
}

variable "openai_temperature" {
  description = "OpenAI temperature setting"
  type        = string
}

# SendGrid Configuration
variable "sendgrid_api_key" {
  description = "SendGrid API Key"
  type        = string
  sensitive   = true
}

variable "sendgrid_from_email" {
  description = "SendGrid from email address"
  type        = string
}

# Application Security
variable "secret_key" {
  description = "Flask Secret Key"
  type        = string
  sensitive   = true
}

variable "jwt_secret_key" {
  description = "JWT Secret Key"
  type        = string
  sensitive   = true
}

# AWS Configuration for application
variable "aws_access_key_id" {
  description = "AWS Access Key ID for application"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for application"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region for application"
  type        = string
}

variable "aws_default_region" {
  description = "AWS default region"
  type        = string
}

# S3 Bucket for Docker Compose files
variable "s3_bucket_name" {
  description = "S3 bucket name for storing Docker Compose files and configurations"
  type        = string
}

########################################
# S3 Bucket Variables for Docker Compose files
########################################

variable "bucket_acl" {
  description = "ACL for the S3 bucket"
  type        = string
}

########################################
# EC2 Module Variables
########################################

variable "use_default_vpc" {
  description = "Whether to use the default VPC"
  type        = bool
}

variable "admin_ssh_cidr" {
  description = "CIDR block for SSH access (your office IP)"
  type        = string
}

########################################
# Networking Variables
########################################

variable "ssh_public_key" {
  description = "SSH public key for EC2 access"
  type        = string
}

########################################
# Domain and DNS Variables
########################################

variable "domain_zone_name" {
  description = "Route53 hosted zone name (e.g., greyzoneapps.com)"
  type        = string
}

variable "sms_frontend_domain" {
  description = "Domain for SMS frontend (e.g., sms.greyzoneapps.com)"
  type        = string
}

variable "sms_api_domain" {
  description = "Domain for SMS API (e.g., api.sms.greyzoneapps.com)"
  type        = string
}

# Optional Car Rental domains (for future expansion)
variable "enable_carrental_domain" {
  description = "Whether to create car rental domain records"
  type        = bool
}

variable "carrental_frontend_domain" {
  description = "Domain for Car Rental frontend"
  type        = string
}

variable "carrental_api_domain" {
  description = "Domain for Car Rental API"
  type        = string
}

########################################
# Application Configuration
########################################

variable "flask_secret_key" {
  description = "Flask secret key"
  type        = string
  sensitive   = true
}

variable "use_postgres" {
  description = "Whether to use PostgreSQL"
  type        = bool
}

variable "database_url" {
  description = "Complete database URL"
  type        = string
  sensitive   = true
}

variable "api_url" {
  description = "API URL"
  type        = string
}

variable "vite_api_url" {
  description = "Vite API URL"
  type        = string
}

variable "backend_url" {
  description = "Backend URL"
  type        = string
}

variable "frontend_url" {
  description = "Frontend URL"
  type        = string
}

variable "backend_port" {
  description = "Backend port"
  type        = string
}

variable "frontend_port" {
  description = "Frontend port"
  type        = string
}

variable "allowed_origins" {
  description = "CORS allowed origins"
  type        = string
}

variable "twilio_webhook_url" {
  description = "Twilio webhook URL"
  type        = string
}

# Ngrok Configuration
variable "ngrok_port" {
  description = "Ngrok port"
  type        = string
}

variable "ngrok_url" {
  description = "Ngrok URL"
  type        = string
}

variable "ngrok_auth_token" {
  description = "Ngrok auth token"
  type        = string
  sensitive   = true
}

variable "ngrok_subdomain" {
  description = "Ngrok subdomain"
  type        = string
}

variable "start_ngrok" {
  description = "Whether to start ngrok"
  type        = bool
}

# Application Settings
variable "debug" {
  description = "Debug mode"
  type        = bool
}

variable "log_level" {
  description = "Log level"
  type        = string
}

# Hot Lead Configuration
variable "hot_lead_webhook_url" {
  description = "Hot lead webhook URL"
  type        = string
}

variable "hot_lead_email_recipients" {
  description = "Hot lead email recipients"
  type        = string
}

variable "hot_lead_sms_recipients" {
  description = "Hot lead SMS recipients"
  type        = string
}

# Rate Limiting Configuration
variable "rate_limit_per_minute" {
  description = "Rate limit per minute"
  type        = string
}

variable "rate_limit_burst" {
  description = "Rate limit burst"
  type        = string
}

# Session Configuration
variable "session_timeout_minutes" {
  description = "Session timeout in minutes"
  type        = string
}

variable "remember_me_days" {
  description = "Remember me duration in days"
  type        = string
}

# File Upload Configuration
variable "max_file_size_mb" {
  description = "Maximum file size in MB"
  type        = string
}

variable "allowed_file_types" {
  description = "Allowed file types"
  type        = string
}

########################################
# Local Variables
########################################

# Note: Locals are defined in locals.tf
