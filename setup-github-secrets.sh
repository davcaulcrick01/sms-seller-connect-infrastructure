#!/bin/bash

# Setup GitHub Actions Secrets and Variables for SMS Seller Connect
# This script reads from terraform.tfvars and automatically categorizes secrets vs variables

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if terraform.tfvars exists
TFVARS_FILE="modules/ec2/terraform.tfvars"
if [ ! -f "$TFVARS_FILE" ]; then
    echo -e "${RED}Error: $TFVARS_FILE not found!${NC}"
    echo -e "${YELLOW}Please make sure you have a terraform.tfvars file with your actual values.${NC}"
    echo -e "${YELLOW}You can copy from terraform.tfvars.template and fill in your values.${NC}"
    exit 1
fi

# Check if GitHub CLI is installed and authenticated
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed!${NC}"
    echo -e "${YELLOW}Please install it from: https://cli.github.com/${NC}"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub CLI!${NC}"
    echo -e "${YELLOW}Please run: gh auth login${NC}"
    exit 1
fi

echo -e "${BLUE}🔐 Setting up GitHub Actions Secrets and Variables...${NC}"
echo -e "${BLUE}Reading from: $TFVARS_FILE${NC}"
echo ""

# Function to extract value from terraform.tfvars
get_tfvar_value() {
    local key=$1
    local value=$(grep "^$key" "$TFVARS_FILE" | sed 's/.*= *"\(.*\)".*/\1/' | head -1)
    if [ -z "$value" ]; then
        value=$(grep "^$key" "$TFVARS_FILE" | sed 's/.*= *\(.*\)/\1/' | head -1)
    fi
    echo "$value"
}

# Function to add GitHub secret
add_secret() {
    local name=$1
    local key=$2
    local value=$(get_tfvar_value "$key")
    
    if [ -n "$value" ] && [ "$value" != "YOUR_${key}" ] && [ "$value" != "\"\"" ]; then
        echo -e "${YELLOW}Adding secret: $name${NC}"
        gh secret set "$name" --body "$value"
        echo -e "${GREEN}✓ Secret $name added${NC}"
    else
        echo -e "${RED}⚠ Skipping $name - no value found or placeholder detected${NC}"
    fi
}

# Function to add GitHub variable
add_variable() {
    local name=$1
    local key=$2
    local value=$(get_tfvar_value "$key")
    
    if [ -n "$value" ] && [ "$value" != "\"\"" ]; then
        echo -e "${YELLOW}Adding variable: $name${NC}"
        gh variable set "$name" --body "$value"
        echo -e "${GREEN}✓ Variable $name added${NC}"
    else
        echo -e "${RED}⚠ Skipping $name - no value found${NC}"
    fi
}

echo -e "${BLUE}📋 Adding GitHub Secrets (sensitive data)...${NC}"

# AWS Credentials
add_secret "AWS_ACCESS_KEY_ID" "aws_access_key_id"
add_secret "AWS_SECRET_ACCESS_KEY" "aws_secret_access_key"

# Database Configuration
add_secret "DB_HOST" "db_host"
add_secret "DB_USER" "db_user"
add_secret "DB_PASSWORD" "db_password"

# Application Security
add_secret "FLASK_SECRET_KEY" "flask_secret_key"
add_secret "JWT_SECRET_KEY" "jwt_secret_key"

# Twilio Configuration
add_secret "TWILIO_ACCOUNT_SID" "twilio_account_sid"
add_secret "TWILIO_AUTH_TOKEN" "twilio_auth_token"
add_secret "TWILIO_PHONE_NUMBER" "twilio_phone_number"

# OpenAI Configuration
add_secret "OPENAI_API_KEY" "openai_api_key"

# SendGrid Configuration
add_secret "SENDGRID_API_KEY" "sendgrid_api_key"

# SSH Configuration
add_secret "SSH_PUBLIC_KEY" "ssh_public_key"

# Ngrok Configuration
add_secret "NGROK_AUTH_TOKEN" "ngrok_auth_token"

# Hot Lead Configuration
add_secret "HOT_LEAD_SMS_RECIPIENTS" "hot_lead_sms_recipients"

echo ""
echo -e "${BLUE}📋 Adding GitHub Variables (non-sensitive configuration)...${NC}"

# Basic Configuration
add_variable "AWS_REGION" "aws_region"
add_variable "PROJECT_NAME" "project_name"

# EC2 Configuration
add_variable "AMI_ID" "ami_id"
add_variable "INSTANCE_TYPE" "instance_type"
add_variable "KEY_NAME" "key_name"
add_variable "INSTANCE_NAME" "instance_name"

# Networking Configuration
add_variable "USE_DEFAULT_VPC" "use_default_vpc"
add_variable "VPC_NAME" "vpc_name"
add_variable "SUBNET_NAME" "subnet_name"
add_variable "SUBNET_NAME_B" "subnet_name_b"
add_variable "ADMIN_SSH_CIDR" "admin_ssh_cidr"

# S3 Configuration
add_variable "S3_BUCKET_NAME" "s3_bucket_name"
add_variable "S3_ACL" "s3_acl"
add_variable "S3_FORCE_DESTROY" "s3_force_destroy"

# Container Configuration
add_variable "ECR_REPO_URL" "ecr_repo_url"
add_variable "CONTAINER_TAG" "container_tag"
add_variable "APP_PORT" "app_port"

# Docker Images
add_variable "BACKEND_IMAGE" "backend_image"
add_variable "FRONTEND_IMAGE" "frontend_image"

# Domain Configuration
add_variable "DOMAIN_ZONE_NAME" "domain_zone_name"
add_variable "DOMAIN_NAME" "domain_name"
add_variable "SMS_FRONTEND_DOMAIN" "sms_frontend_domain"
add_variable "SMS_API_DOMAIN" "sms_api_domain"

# Optional Car Rental Domains
add_variable "ENABLE_CARRENTAL_DOMAIN" "enable_carrental_domain"
add_variable "CARRENTAL_FRONTEND_DOMAIN" "carrental_frontend_domain"
add_variable "CARRENTAL_API_DOMAIN" "carrental_api_domain"

# Monitoring Configuration
add_variable "ALERT_EMAIL" "alert_email"

# Database Configuration (Non-Sensitive)
add_variable "DB_PORT" "db_port"
add_variable "DB_NAME" "db_name"
add_variable "USE_POSTGRES" "use_postgres"

# OpenAI Configuration (Non-Sensitive)
add_variable "OPENAI_MODEL" "openai_model"
add_variable "OPENAI_TEMPERATURE" "openai_temperature"

# SendGrid Configuration (Non-Sensitive)
add_variable "SENDGRID_FROM_EMAIL" "sendgrid_from_email"

# Application Ports
add_variable "BACKEND_PORT" "backend_port"
add_variable "FRONTEND_PORT" "frontend_port"

# Ngrok Configuration (Non-Sensitive)
add_variable "NGROK_PORT" "ngrok_port"
add_variable "NGROK_URL" "ngrok_url"
add_variable "NGROK_SUBDOMAIN" "ngrok_subdomain"
add_variable "START_NGROK" "start_ngrok"

# Application Settings
add_variable "DEBUG" "debug"
add_variable "LOG_LEVEL" "log_level"

# Hot Lead Configuration (Non-Sensitive)
add_variable "HOT_LEAD_EMAIL_RECIPIENTS" "hot_lead_email_recipients"

# Rate Limiting Configuration
add_variable "RATE_LIMIT_PER_MINUTE" "rate_limit_per_minute"
add_variable "RATE_LIMIT_BURST" "rate_limit_burst"

# Session Configuration
add_variable "SESSION_TIMEOUT_MINUTES" "session_timeout_minutes"
add_variable "REMEMBER_ME_DAYS" "remember_me_days"

# File Upload Configuration
add_variable "MAX_FILE_SIZE_MB" "max_file_size_mb"
add_variable "ALLOWED_FILE_TYPES" "allowed_file_types"

# Extract tags from the tags block (more complex parsing)
PROJECT_TAG=$(grep -A 10 'tags = {' "$TFVARS_FILE" | grep 'Project' | sed 's/.*= *"\(.*\)".*/\1/')
OWNER_TAG=$(grep -A 10 'tags = {' "$TFVARS_FILE" | grep 'Owner' | sed 's/.*= *"\(.*\)".*/\1/')

if [ -n "$PROJECT_TAG" ]; then
    echo -e "${YELLOW}Adding variable: PROJECT_TAG${NC}"
    gh variable set "PROJECT_TAG" --body "$PROJECT_TAG"
    echo -e "${GREEN}✓ Variable PROJECT_TAG added${NC}"
fi

if [ -n "$OWNER_TAG" ]; then
    echo -e "${YELLOW}Adding variable: OWNER_TAG${NC}"
    gh variable set "OWNER_TAG" --body "$OWNER_TAG"
    echo -e "${GREEN}✓ Variable OWNER_TAG added${NC}"
fi

echo ""
echo -e "${GREEN}🎉 GitHub Actions Secrets and Variables setup complete!${NC}"
echo -e "${BLUE}You can now run your GitHub Actions workflow.${NC}"
echo ""
echo -e "${YELLOW}📋 Summary:${NC}"
echo -e "${YELLOW}- Secrets contain sensitive data (API keys, passwords, etc.)${NC}"
echo -e "${YELLOW}- Variables contain non-sensitive configuration${NC}"
echo -e "${YELLOW}- All values were read from your local terraform.tfvars file${NC}"
echo ""
echo -e "${BLUE}🔗 Check your repository settings:${NC}"
echo -e "${BLUE}https://github.com/davcaulcrick01/sms-seller-connect-infrastructure/settings/secrets/actions${NC}" 