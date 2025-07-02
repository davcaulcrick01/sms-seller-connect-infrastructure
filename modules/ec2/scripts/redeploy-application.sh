#!/bin/bash

# SMS Seller Connect Application Redeployment Script
# This script redeploys the application without destroying the EC2 instance
# It downloads fresh configuration from S3 and restarts all services

set -e

# Configuration
SCRIPT_DIR="/tmp/sms-redeploy-$(date +%s)"
LOG_FILE="/var/log/sms-redeploy.log"
APP_DIR="/app/sms-seller-connect"
BACKUP_DIR="/app/backups/$(date +%Y%m%d_%H%M%S)"

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    echo "[$timestamp] [$level] Redeploy: $message" | tee -a "$LOG_FILE"
}

# Error handling
handle_error() {
    log_message "ERROR" "Redeployment failed on line $1"
    log_message "ERROR" "Check logs at $LOG_FILE for details"
    exit 1
}

trap 'handle_error $LINENO' ERR

# Create working directory
mkdir -p "$SCRIPT_DIR"
mkdir -p "$BACKUP_DIR"
cd "$SCRIPT_DIR"

log_message "INFO" "=== Starting SMS Seller Connect Application Redeployment ==="
log_message "INFO" "Working directory: $SCRIPT_DIR"
log_message "INFO" "Backup directory: $BACKUP_DIR"

# Function to validate required environment variables
validate_environment() {
    log_message "INFO" "Validating environment variables..."
    
    local required_vars=(
        "BACKEND_IMAGE"
        "FRONTEND_IMAGE" 
        "SMS_API_DOMAIN"
        "SMS_FRONTEND_DOMAIN"
        "AWS_REGION"
        "S3_BUCKET"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_message "ERROR" "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    log_message "INFO" "✅ All required environment variables are set"
    
    # Log key variables for debugging
    log_message "INFO" "DEBUG: BACKEND_IMAGE=${BACKEND_IMAGE}"
    log_message "INFO" "DEBUG: FRONTEND_IMAGE=${FRONTEND_IMAGE}"
    log_message "INFO" "DEBUG: SMS_API_DOMAIN=${SMS_API_DOMAIN}"
    log_message "INFO" "DEBUG: SMS_FRONTEND_DOMAIN=${SMS_FRONTEND_DOMAIN}"
}

# Function to backup current configuration
backup_current_config() {
    log_message "INFO" "Backing up current configuration..."
    
    if [ -d "$APP_DIR" ]; then
        sudo cp -r "$APP_DIR" "$BACKUP_DIR/"
        log_message "INFO" "✅ Current configuration backed up to $BACKUP_DIR"
    else
        log_message "WARN" "No existing application directory found"
    fi
}

# Function to download fresh configuration from S3
download_fresh_config() {
    log_message "INFO" "Downloading fresh configuration and scripts from S3..."
    
    # Create application directory if it doesn't exist
    sudo mkdir -p "$APP_DIR"
    cd "$APP_DIR"
    
    # Remove existing scripts to ensure clean replacement
    log_message "INFO" "Removing existing scripts for clean replacement..."
    sudo rm -f *.sh *.py docker-compose.yml nginx.conf .env.template || true
    
    # Download Docker Compose configuration
    log_message "INFO" "Downloading Docker Compose configuration..."
    sudo aws s3 cp "s3://${S3_BUCKET}/docker-compose/docker-compose.yml" ./docker-compose.yml || {
        log_message "ERROR" "Failed to download docker-compose.yml"
        return 1
    }
    
    # Download environment template
    log_message "INFO" "Downloading environment template..."
    sudo aws s3 cp "s3://${S3_BUCKET}/docker-compose/.env.template" ./.env.template || {
        log_message "WARN" "Failed to download .env.template, continuing..."
    }
    
    # Download Nginx configuration
    log_message "INFO" "Downloading Nginx configuration..."
    sudo aws s3 cp "s3://${S3_BUCKET}/nginx/nginx.conf" ./nginx.conf || {
        log_message "ERROR" "Failed to download nginx.conf"
        return 1
    }
    
    # Download ALL scripts from S3 scripts folder (replace any existing)
    log_message "INFO" "Downloading ALL scripts from S3 (replacing existing)..."
    
    # List all scripts in S3 and download them
    SCRIPT_LIST=$(aws s3 ls "s3://${S3_BUCKET}/scripts/" --recursive | awk '{print $4}' | grep -E '\.(sh|py)$' || true)
    
    if [ -n "$SCRIPT_LIST" ]; then
        while IFS= read -r script_path; do
            if [ -n "$script_path" ]; then
                script_name=$(basename "$script_path")
                log_message "INFO" "Downloading script: $script_name"
                sudo aws s3 cp "s3://${S3_BUCKET}/$script_path" "./$script_name" || {
                    log_message "WARN" "Failed to download $script_name, continuing..."
                }
            fi
        done <<< "$SCRIPT_LIST"
    else
        log_message "WARN" "No scripts found in S3 bucket scripts folder"
    fi
    
    # Download specific critical scripts with error handling
    CRITICAL_SCRIPTS=(
        "health-check.sh"
        "health-check-server.py"
        "maintenance.sh"
        "redeploy-application.sh"
        "user_data.sh"
        "bootstrap.sh"
    )
    
    for script in "${CRITICAL_SCRIPTS[@]}"; do
        if [ ! -f "$script" ]; then
            log_message "INFO" "Downloading critical script: $script"
            sudo aws s3 cp "s3://${S3_BUCKET}/scripts/$script" "./$script" || {
                log_message "WARN" "Critical script $script not found in S3, continuing..."
            }
        fi
    done
    
    # Set proper permissions for all files
    log_message "INFO" "Setting proper permissions for all downloaded files..."
    sudo chown -R ec2-user:ec2-user "$APP_DIR"
    
    # Set permissions for configuration files
    sudo chmod 644 docker-compose.yml nginx.conf .env.template *.py 2>/dev/null || true
    
    # Set executable permissions for shell scripts
    sudo chmod 755 *.sh 2>/dev/null || true
    
    # Create symlinks for commonly used scripts
    log_message "INFO" "Creating convenient symlinks for scripts..."
    sudo ln -sf "$APP_DIR/maintenance.sh" /usr/local/bin/sms-maintenance 2>/dev/null || true
    sudo ln -sf "$APP_DIR/health-check.sh" /usr/local/bin/sms-health 2>/dev/null || true
    
    # Log what was downloaded
    log_message "INFO" "Downloaded files summary:"
    ls -la "$APP_DIR" | grep -E '\.(sh|py|yml|conf)$' | while read -r line; do
        log_message "INFO" "  $line"
    done
    
    log_message "INFO" "✅ Fresh configuration and scripts downloaded and replaced from S3"
}

# Function to create environment file with all variables
create_environment_file() {
    log_message "INFO" "Creating environment file with current variables..."
    
    cd "$APP_DIR"
    
    # Create .env file with all current environment variables
    cat > .env << EOF
# Docker Images
BACKEND_IMAGE=${BACKEND_IMAGE}
FRONTEND_IMAGE=${FRONTEND_IMAGE}

# Domain Configuration
SMS_API_DOMAIN=${SMS_API_DOMAIN}
SMS_FRONTEND_DOMAIN=${SMS_FRONTEND_DOMAIN}

# Database Configuration
DB_HOST=${DB_HOST:-}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-sms_seller_connect}
DB_USER=${DB_USER:-}
DB_PASSWORD=${DB_PASSWORD:-}

# Twilio Configuration
TWILIO_ACCOUNT_SID=${TWILIO_ACCOUNT_SID:-}
TWILIO_AUTH_TOKEN=${TWILIO_AUTH_TOKEN:-}
TWILIO_PHONE_NUMBER=${TWILIO_PHONE_NUMBER:-}

# OpenAI Configuration
OPENAI_API_KEY=${OPENAI_API_KEY:-}
OPENAI_MODEL=${OPENAI_MODEL:-gpt-4o}
OPENAI_TEMPERATURE=${OPENAI_TEMPERATURE:-0.3}

# Application Security
FLASK_SECRET_KEY=${SECRET_KEY:-}
SECRET_KEY=${SECRET_KEY:-}
JWT_SECRET_KEY=${JWT_SECRET_KEY:-}

# AWS Configuration
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}
AWS_REGION=${AWS_REGION:-us-east-1}
S3_BUCKET_NAME=${S3_BUCKET_NAME:-grey-database-bucket}

# SendGrid Configuration
SENDGRID_API_KEY=${SENDGRID_API_KEY:-}
SENDGRID_FROM_EMAIL=${SENDGRID_FROM_EMAIL:-}

# Hot Lead Alert Configuration
HOT_LEAD_EMAIL_RECIPIENTS=${HOT_LEAD_EMAIL_RECIPIENTS:-admin@greyzonesolutions.com}
HOT_LEAD_SMS_RECIPIENTS=${HOT_LEAD_SMS_RECIPIENTS:-+14693785661}

# Rate Limiting Configuration
RATE_LIMIT_PER_MINUTE=${RATE_LIMIT_PER_MINUTE:-60}
RATE_LIMIT_BURST=${RATE_LIMIT_BURST:-10}

# Session Configuration
SESSION_TIMEOUT_MINUTES=${SESSION_TIMEOUT_MINUTES:-60}
REMEMBER_ME_DAYS=${REMEMBER_ME_DAYS:-30}

# File Upload Configuration
MAX_FILE_SIZE_MB=${MAX_FILE_SIZE_MB:-10}
ALLOWED_FILE_TYPES=${ALLOWED_FILE_TYPES:-pdf,jpg,jpeg,png,doc,docx,csv}

# Environment
ENVIRONMENT=${ENVIRONMENT:-prod}
EOF

    # Set secure permissions on .env file
    sudo chown ec2-user:ec2-user .env
    sudo chmod 600 .env
    
    log_message "INFO" "✅ Environment file created with $(wc -l < .env) variables"
}

# Function to stop existing services gracefully
stop_existing_services() {
    log_message "INFO" "Stopping existing services..."
    
    cd "$APP_DIR"
    
    # Stop Docker Compose services if running
    if sudo docker-compose ps -q | grep -q .; then
        log_message "INFO" "Stopping Docker Compose services..."
        sudo docker-compose down --timeout 30
        log_message "INFO" "✅ Services stopped"
    else
        log_message "INFO" "No running services found"
    fi
    
    # Clean up any orphaned containers
    log_message "INFO" "Cleaning up orphaned containers..."
    sudo docker container prune -f || true
    
    # Clean up unused networks
    sudo docker network prune -f || true
}

# Function to pull latest images
pull_latest_images() {
    log_message "INFO" "Pulling latest Docker images..."
    
    cd "$APP_DIR"
    
    # Login to ECR
    log_message "INFO" "Logging into Amazon ECR..."
    ECR_REGISTRY="522814698925.dkr.ecr.us-east-1.amazonaws.com"
    sudo aws ecr get-login-password --region "${AWS_REGION}" | sudo docker login --username AWS --password-stdin "$ECR_REGISTRY"
    
    # Pull images
    log_message "INFO" "Pulling images specified in docker-compose.yml..."
    sudo docker-compose pull
    
    log_message "INFO" "✅ Latest images pulled successfully"
}

# Function to start services
start_services() {
    log_message "INFO" "Starting services..."
    
    cd "$APP_DIR"
    
    # Start services with Docker Compose
    log_message "INFO" "Starting Docker Compose services..."
    sudo docker-compose up -d
    
    # Wait for services to start
    log_message "INFO" "Waiting for services to start..."
    sleep 30
    
    log_message "INFO" "✅ Services started"
}

# Function to verify deployment
verify_deployment() {
    log_message "INFO" "Verifying deployment..."
    
    cd "$APP_DIR"
    
    # Check container status
    log_message "INFO" "Checking container status..."
    local running_containers=$(sudo docker-compose ps --services --filter "status=running" | wc -l)
    local total_containers=$(sudo docker-compose ps --services | wc -l)
    
    log_message "INFO" "Running containers: $running_containers/$total_containers"
    
    # Show container status
    sudo docker-compose ps
    
    # Test health endpoints with retries
    local max_retries=6
    local retry_delay=10
    
    for endpoint in "localhost:80/alb-health" "localhost:8900/health" "localhost:8082"; do
        log_message "INFO" "Testing endpoint: $endpoint"
        
        for ((i=1; i<=max_retries; i++)); do
            if curl -f -s "http://$endpoint" > /dev/null 2>&1; then
                log_message "INFO" "✅ $endpoint is responding"
                break
            else
                if [ $i -eq $max_retries ]; then
                    log_message "WARN" "⚠️ $endpoint is not responding after $max_retries attempts"
                else
                    log_message "INFO" "Attempt $i/$max_retries failed for $endpoint, retrying in ${retry_delay}s..."
                    sleep $retry_delay
                fi
            fi
        done
    done
    
    log_message "INFO" "✅ Deployment verification completed"
}

# Function to cleanup
cleanup() {
    log_message "INFO" "Cleaning up temporary files..."
    rm -rf "$SCRIPT_DIR"
    log_message "INFO" "✅ Cleanup completed"
}

# Main execution
main() {
    validate_environment
    backup_current_config
    download_fresh_config
    create_environment_file
    stop_existing_services
    pull_latest_images
    start_services
    verify_deployment
    cleanup
    
    log_message "INFO" "🎉 SMS Seller Connect redeployment completed successfully!"
    log_message "INFO" "Backup available at: $BACKUP_DIR"
    log_message "INFO" "Application logs: sudo docker-compose logs"
    log_message "INFO" "Service status: sudo docker-compose ps"
}

# Run main function
main "$@" 