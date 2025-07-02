#!/bin/bash

# Manual Bootstrap Fix Script for SMS Seller Connect EC2
# This script manually sets the environment variables and runs the user_data script
# with the correct values that should have been templated by Terraform

set -e

echo "🔧 Starting manual bootstrap fix..."

# Set all the environment variables that should have been templated
export AWS_REGION="us-east-1"
export S3_BUCKET="sms-seller-connect-bucket"
export CLOUDWATCH_LOG_GROUP="/aws/ec2/sms-seller-connect"
export CLOUDWATCH_LOG_STREAM="application"

# Docker Images (using the fallback values from GitHub Actions)
# Get the latest image tags from ECR instead of hardcoding :latest
LATEST_BACKEND_TAG=$(aws ecr describe-images --repository-name sms-wholesaling-backend \
  --region us-east-1 --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' \
  --output text 2>/dev/null || echo "latest")
LATEST_FRONTEND_TAG=$(aws ecr describe-images --repository-name sms-wholesaling-frontend \
  --region us-east-1 --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' \
  --output text 2>/dev/null || echo "latest")

export BACKEND_IMAGE="522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-backend:${LATEST_BACKEND_TAG}"
export FRONTEND_IMAGE="522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-frontend:${LATEST_FRONTEND_TAG}"

# Domain Configuration
export SMS_API_DOMAIN="api.sms.typerelations.com"
export SMS_FRONTEND_DOMAIN="sms.typerelations.com"

# Database Configuration (using placeholder values - these should be set from GitHub secrets)
export DB_HOST="your-db-host"
export DB_PORT="5432"
export DB_NAME="sms_seller_connect"
export DB_USER="your-db-user"
export DB_PASSWORD="your-db-password"

# Application Configuration (placeholders - should be from GitHub secrets)
export SECRET_KEY="your-secret-key"
export JWT_SECRET_KEY="your-jwt-secret-key"
export TWILIO_ACCOUNT_SID="your-twilio-sid"
export TWILIO_AUTH_TOKEN="your-twilio-token"
export TWILIO_PHONE_NUMBER="your-twilio-phone"
export OPENAI_API_KEY="your-openai-key"
export OPENAI_MODEL="gpt-4o"
export OPENAI_TEMPERATURE="0.3"

# SendGrid Configuration
export SENDGRID_API_KEY="your-sendgrid-key"
export SENDGRID_FROM_EMAIL="your-from-email"

# AWS Application Configuration
export AWS_ACCESS_KEY_ID="your-aws-key"
export AWS_SECRET_ACCESS_KEY="your-aws-secret"
export S3_BUCKET_NAME="grey-database-bucket"

# Hot Lead Alert Configuration
export HOT_LEAD_EMAIL_RECIPIENTS="admin@greyzonesolutions.com"
export HOT_LEAD_SMS_RECIPIENTS="+14693785661"

# Rate Limiting Configuration
export RATE_LIMIT_PER_MINUTE="60"
export RATE_LIMIT_BURST="10"

# Session Configuration
export SESSION_TIMEOUT_MINUTES="60"
export REMEMBER_ME_DAYS="30"

# File Upload Configuration
export MAX_FILE_SIZE_MB="10"
export ALLOWED_FILE_TYPES="pdf,jpg,jpeg,png,doc,docx,csv"

# Environment
export ENVIRONMENT="prod"

echo "✅ Environment variables set"

# Stop any existing containers
echo "🛑 Stopping existing containers..."
cd /app/sms-seller-connect || { echo "App directory not found"; exit 1; }
sudo docker-compose down || echo "No containers to stop"

# Create new .env file with correct values
echo "📝 Creating new .env file..."
cat > .env << EOF
BACKEND_IMAGE=${BACKEND_IMAGE}
FRONTEND_IMAGE=${FRONTEND_IMAGE}
SMS_API_DOMAIN=${SMS_API_DOMAIN}
SMS_FRONTEND_DOMAIN=${SMS_FRONTEND_DOMAIN}
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
TWILIO_ACCOUNT_SID=${TWILIO_ACCOUNT_SID}
TWILIO_AUTH_TOKEN=${TWILIO_AUTH_TOKEN}
TWILIO_PHONE_NUMBER=${TWILIO_PHONE_NUMBER}
OPENAI_API_KEY=${OPENAI_API_KEY}
OPENAI_MODEL=${OPENAI_MODEL}
OPENAI_TEMPERATURE=${OPENAI_TEMPERATURE}
FLASK_SECRET_KEY=${SECRET_KEY}
SECRET_KEY=${SECRET_KEY}
JWT_SECRET_KEY=${JWT_SECRET_KEY}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
AWS_REGION=${AWS_REGION}
S3_BUCKET_NAME=${S3_BUCKET_NAME}
SENDGRID_API_KEY=${SENDGRID_API_KEY}
SENDGRID_FROM_EMAIL=${SENDGRID_FROM_EMAIL}
HOT_LEAD_EMAIL_RECIPIENTS=${HOT_LEAD_EMAIL_RECIPIENTS}
HOT_LEAD_SMS_RECIPIENTS=${HOT_LEAD_SMS_RECIPIENTS}
RATE_LIMIT_PER_MINUTE=${RATE_LIMIT_PER_MINUTE}
RATE_LIMIT_BURST=${RATE_LIMIT_BURST}
SESSION_TIMEOUT_MINUTES=${SESSION_TIMEOUT_MINUTES}
REMEMBER_ME_DAYS=${REMEMBER_ME_DAYS}
MAX_FILE_SIZE_MB=${MAX_FILE_SIZE_MB}
ALLOWED_FILE_TYPES=${ALLOWED_FILE_TYPES}
EOF

echo "✅ Environment file created"

# Set proper permissions
sudo chown ec2-user:ec2-user .env
sudo chmod 600 .env

# Pull the latest images
echo "📥 Pulling Docker images..."
sudo docker-compose pull

# Start the services
echo "🚀 Starting services..."
sudo docker-compose up -d

echo "✅ Services started"

# Check status
echo "📊 Checking container status..."
sudo docker-compose ps

echo "🎉 Manual bootstrap fix completed!"
echo ""
echo "To verify the fix worked:"
echo "1. Check container status: sudo docker-compose ps"
echo "2. Check logs: sudo docker-compose logs"
echo "3. Test the application: curl http://localhost:80/alb-health" 