#!/bin/bash

# Simple Bootstrap Script for SMS Seller Connect EC2
# Downloads and executes the main user_data.sh script from S3
# This allows the user_data script to be updated without recreating the EC2 instance

set -e

# Configuration
S3_BUCKET="${S3_BUCKET}"
AWS_REGION="${AWS_REGION}"
SCRIPT_PATH="/tmp/user_data.sh"
LOG_FILE="/var/log/bootstrap.log"

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    echo "[$timestamp] [$level] Bootstrap: $message" | tee -a "$LOG_FILE"
}

# Error handling
handle_error() {
    log_message "ERROR" "Bootstrap failed on line $1"
    exit 1
}

trap 'handle_error $LINENO' ERR

# Main bootstrap function
main() {
    log_message "INFO" "=== Starting SMS Seller Connect Bootstrap ==="
    log_message "INFO" "S3 Bucket: $S3_BUCKET"
    log_message "INFO" "AWS Region: $AWS_REGION"
    
    # Update system packages
    log_message "INFO" "Updating system packages..."
    yum update -y
    
    # Install AWS CLI if not present
    if ! command -v aws &> /dev/null; then
        log_message "INFO" "Installing AWS CLI..."
        yum install -y aws-cli
    fi
    
    # Download the main user_data script from S3
    log_message "INFO" "Downloading user_data.sh from S3..."
    aws s3 cp "s3://$S3_BUCKET/scripts/user_data.sh" "$SCRIPT_PATH" --region "$AWS_REGION"
    
    # Make the script executable
    chmod +x "$SCRIPT_PATH"
    
    # Export all environment variables for the user_data script
    log_message "INFO" "Exporting environment variables..."
    export AWS_REGION="${AWS_REGION}"
    export S3_BUCKET="${S3_BUCKET}"
    export CLOUDWATCH_LOG_GROUP="${CLOUDWATCH_LOG_GROUP}"
    export CLOUDWATCH_LOG_STREAM="${CLOUDWATCH_LOG_STREAM}"
    
    # Docker Images
    export BACKEND_IMAGE="${BACKEND_IMAGE}"
    export FRONTEND_IMAGE="${FRONTEND_IMAGE}"
    
    # Domain Configuration
    export SMS_API_DOMAIN="${SMS_API_DOMAIN}"
    export SMS_FRONTEND_DOMAIN="${SMS_FRONTEND_DOMAIN}"
    
    # Database Configuration
    export DB_HOST="${DB_HOST}"
    export DB_PORT="${DB_PORT}"
    export DB_NAME="${DB_NAME}"
    export DB_USER="${DB_USER}"
    export DB_PASSWORD="${DB_PASSWORD}"
    
    # Application Configuration
    export SECRET_KEY="${SECRET_KEY}"
    export JWT_SECRET_KEY="${JWT_SECRET_KEY}"
    export TWILIO_ACCOUNT_SID="${TWILIO_ACCOUNT_SID}"
    export TWILIO_AUTH_TOKEN="${TWILIO_AUTH_TOKEN}"
    export TWILIO_PHONE_NUMBER="${TWILIO_PHONE_NUMBER}"
    export OPENAI_API_KEY="${OPENAI_API_KEY}"
    export OPENAI_MODEL="${OPENAI_MODEL}"
    export OPENAI_TEMPERATURE="${OPENAI_TEMPERATURE}"
    
    # SendGrid Configuration
    export SENDGRID_API_KEY="${SENDGRID_API_KEY}"
    export SENDGRID_FROM_EMAIL="${SENDGRID_FROM_EMAIL}"
    
    # AWS Application Configuration
    export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
    export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
    export S3_BUCKET_NAME="${S3_BUCKET_NAME}"
    
    # Hot Lead Alert Configuration
    export HOT_LEAD_EMAIL_RECIPIENTS="${HOT_LEAD_EMAIL_RECIPIENTS}"
    export HOT_LEAD_SMS_RECIPIENTS="${HOT_LEAD_SMS_RECIPIENTS}"
    
    # Rate Limiting Configuration
    export RATE_LIMIT_PER_MINUTE="${RATE_LIMIT_PER_MINUTE}"
    export RATE_LIMIT_BURST="${RATE_LIMIT_BURST}"
    
    # Session Configuration
    export SESSION_TIMEOUT_MINUTES="${SESSION_TIMEOUT_MINUTES}"
    export REMEMBER_ME_DAYS="${REMEMBER_ME_DAYS}"
    
    # File Upload Configuration
    export MAX_FILE_SIZE_MB="${MAX_FILE_SIZE_MB}"
    export ALLOWED_FILE_TYPES="${ALLOWED_FILE_TYPES}"
    
    # Environment
    export ENVIRONMENT="${ENVIRONMENT}"
    
    # Debug: Log some key variables to verify they're set
    log_message "INFO" "DEBUG: BACKEND_IMAGE=${BACKEND_IMAGE}"
    log_message "INFO" "DEBUG: FRONTEND_IMAGE=${FRONTEND_IMAGE}"
    log_message "INFO" "DEBUG: SMS_API_DOMAIN=${SMS_API_DOMAIN}"
    log_message "INFO" "DEBUG: DB_HOST=${DB_HOST}"
    
    # Execute the main user_data script
    log_message "INFO" "Executing main user_data.sh script..."
    bash "$SCRIPT_PATH"
    
    # Cleanup
    log_message "INFO" "Cleaning up temporary files..."
    rm -f "$SCRIPT_PATH"
    
    log_message "INFO" "🎉 Bootstrap completed successfully!"
}

# Run main function
main "$@" 