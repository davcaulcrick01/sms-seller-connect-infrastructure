#!/bin/bash

# SMS Seller Connect Application Redeployment Script
# This script redeploys the application without destroying the EC2 instance
# It downloads fresh configuration from S3 and restarts all services

set -e

# Configuration
LOG_FILE="/var/log/redeploy-application.log"

# Comprehensive error handling
exec 2> >(tee -a "$LOG_FILE" >&2)
exec 1> >(tee -a "$LOG_FILE")

# Error trap function with enhanced diagnostics
error_exit() {
    local line_no=$1
    local error_code=$2
    echo "❌ ERROR: Script failed at line $line_no with exit code $error_code"
    echo "❌ Last command: $BASH_COMMAND"
    echo "❌ Function: ${FUNCNAME[1]:-main}"
    echo "❌ Call stack: ${FUNCNAME[*]}"
    echo "❌ Current directory: $(pwd 2>/dev/null || echo 'unknown')"
    echo "❌ Environment check:"
    echo "  - User: $(whoami 2>/dev/null || echo 'unknown')"
    echo "  - Docker: $(docker --version 2>/dev/null || echo 'not available')"
    echo "  - AWS CLI: $(aws --version 2>/dev/null || echo 'not available')"
    echo "  - Sudo access: $(sudo -n true 2>/dev/null && echo 'available' || echo 'not available')"
    
    echo "📋 Recent log entries:"
    tail -20 "$LOG_FILE" 2>/dev/null || echo "No log file available"
    
    echo "📋 System info:"
    echo "  - Disk space: $(df -h / 2>/dev/null | tail -1 || echo 'unknown')"
    echo "  - Memory: $(free -h 2>/dev/null | head -2 | tail -1 || echo 'unknown')"
    echo "  - Docker status: $(sudo systemctl is-active docker 2>/dev/null || echo 'unknown')"
    
    exit $error_code
}

# Set up error trap (remove the conflicting one later)
trap 'error_exit $LINENO $?' ERR

# Unified logging function 
log_message() {
    local level="${1:-INFO}"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    echo "[$timestamp] [$level] Redeploy: $message" | tee -a "$LOG_FILE"
}

log_message "INFO" "🚀 Starting SMS Seller Connect Application Redeployment"
log_message "INFO" "📋 Script PID: $$"
log_message "INFO" "📋 Running as user: $(whoami)"
log_message "INFO" "📋 Working directory: $(pwd)"
log_message "INFO" "📋 Log file: $LOG_FILE"

SCRIPT_DIR="/tmp/sms-redeploy-$(date +%s)"
APP_DIR="/app/sms-seller-connect"
BACKUP_DIR="/app/backups/$(date +%Y%m%d_%H%M%S)"

# Initial system check
log_message "INFO" "📋 Initial system checks:"
log_message "INFO" "  - Docker: $(docker --version 2>/dev/null || echo 'ERROR: Docker not available')"
log_message "INFO" "  - AWS CLI: $(aws --version 2>/dev/null || echo 'ERROR: AWS CLI not available')"
log_message "INFO" "  - Sudo: $(sudo -n true 2>/dev/null && echo 'available' || echo 'ERROR: Sudo not available')"
log_message "INFO" "  - Disk space: $(df -h / 2>/dev/null | tail -1 || echo 'ERROR: Cannot check disk space')"

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
    
    # First check if essential services are available
    if ! command -v aws >/dev/null 2>&1; then
        log_message "ERROR" "AWS CLI is not installed or not in PATH"
        return 1
    fi
    
    if ! command -v docker >/dev/null 2>&1; then
        log_message "ERROR" "Docker is not installed or not in PATH"
        return 1
    fi
    
    if ! sudo -n true 2>/dev/null; then
        log_message "ERROR" "Script requires sudo access but it's not available"
        return 1
    fi
    
    # Check Docker daemon status
    if ! sudo systemctl is-active docker >/dev/null 2>&1; then
        log_message "WARN" "Docker service is not active, attempting to start..."
        sudo systemctl start docker || {
            log_message "ERROR" "Failed to start Docker service"
            return 1
        }
        sleep 5
    fi
    
    # Required variables - check them individually with detailed logging
    local required_vars=(
        "BACKEND_IMAGE"
        "FRONTEND_IMAGE" 
        "SMS_API_DOMAIN"
        "SMS_FRONTEND_DOMAIN"
        "AWS_REGION"
        "S3_BUCKET"
    )
    
    local missing_vars=()
    local all_env_vars=""
    
    log_message "INFO" "Checking individual environment variables:"
    
    for var in "${required_vars[@]}"; do
        local value="${!var}"
        if [ -z "$value" ]; then
            missing_vars+=("$var")
            log_message "ERROR" "  ❌ $var: NOT SET"
        else
            log_message "INFO" "  ✅ $var: ${value:0:20}..." # Only show first 20 chars for security
            all_env_vars="$all_env_vars $var"
        fi
    done
    
    # Check optional but important variables
    local optional_vars=(
        "DB_HOST"
        "DB_USER"
        "DB_PASSWORD"
        "TWILIO_ACCOUNT_SID"
        "OPENAI_API_KEY"
        "SECRET_KEY"
    )
    
    log_message "INFO" "Checking optional environment variables:"
    for var in "${optional_vars[@]}"; do
        local value="${!var}"
        if [ -z "$value" ]; then
            log_message "WARN" "  ⚠️ $var: NOT SET (optional)"
        else
            log_message "INFO" "  ✅ $var: ***SET***"
        fi
    done
    
    # Check if we have any missing required variables
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_message "ERROR" "Missing required environment variables: ${missing_vars[*]}"
        log_message "ERROR" "Please ensure all required variables are set in the environment"
        log_message "ERROR" "You can check what's available with: printenv | grep -E '(BACKEND_IMAGE|FRONTEND_IMAGE|SMS_|AWS_|S3_)'"
        return 1
    fi
    
    # Test AWS credentials
    log_message "INFO" "Testing AWS credentials..."
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_message "ERROR" "AWS credentials test failed - cannot access AWS services"
        return 1
    fi
    
    # Test S3 bucket access
    log_message "INFO" "Testing S3 bucket access..."
    if ! aws s3 ls "s3://${S3_BUCKET}/" >/dev/null 2>&1; then
        log_message "ERROR" "Cannot access S3 bucket: ${S3_BUCKET}"
        return 1
    fi
    
    log_message "INFO" "✅ All required environment variables are set and validated"
    log_message "INFO" "✅ AWS credentials and S3 access confirmed"
    
    # Log final validation summary (safe values only)
    log_message "INFO" "Environment validation summary:"
    log_message "INFO" "  - AWS Region: ${AWS_REGION}"
    log_message "INFO" "  - S3 Bucket: ${S3_BUCKET}"
    log_message "INFO" "  - Frontend Domain: ${SMS_FRONTEND_DOMAIN}"
    log_message "INFO" "  - API Domain: ${SMS_API_DOMAIN}"
    log_message "INFO" "  - Backend Image: ${BACKEND_IMAGE:0:50}..."
    log_message "INFO" "  - Frontend Image: ${FRONTEND_IMAGE:0:50}..."
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
    
    # Validate S3 access before proceeding
    if ! aws s3 ls "s3://${S3_BUCKET}/" >/dev/null 2>&1; then
        log_message "ERROR" "Cannot access S3 bucket ${S3_BUCKET} for configuration download"
        return 1
    fi
    
    # Create application directory if it doesn't exist
    log_message "INFO" "Creating application directory: $APP_DIR"
    if ! sudo mkdir -p "$APP_DIR"; then
        log_message "ERROR" "Failed to create application directory: $APP_DIR"
        return 1
    fi
    
    # Change to app directory
    if ! cd "$APP_DIR"; then
        log_message "ERROR" "Failed to change to application directory: $APP_DIR"
        return 1
    fi
    
    log_message "INFO" "Working in directory: $(pwd)"
    
    # Remove existing scripts to ensure clean replacement
    log_message "INFO" "Removing existing scripts for clean replacement..."
    sudo rm -f *.sh *.py docker-compose.yml nginx.conf .env.template || true
    log_message "INFO" "Cleanup completed"
    
    # Download Docker Compose configuration
    log_message "INFO" "Downloading Docker Compose configuration..."
    if aws s3 ls "s3://${S3_BUCKET}/docker-compose/docker-compose.yml" >/dev/null 2>&1; then
        if sudo aws s3 cp "s3://${S3_BUCKET}/docker-compose/docker-compose.yml" ./docker-compose.yml; then
            log_message "INFO" "✅ Downloaded docker-compose.yml successfully"
        else
            log_message "ERROR" "Failed to download docker-compose.yml"
            return 1
        fi
    else
        log_message "ERROR" "docker-compose.yml not found in S3 bucket"
        return 1
    fi
    
    # Download environment template
    log_message "INFO" "Downloading environment template..."
    if aws s3 ls "s3://${S3_BUCKET}/docker-compose/.env.template" >/dev/null 2>&1; then
        if sudo aws s3 cp "s3://${S3_BUCKET}/docker-compose/.env.template" ./.env.template; then
            log_message "INFO" "✅ Downloaded .env.template successfully"
        else
            log_message "WARN" "Failed to download .env.template, continuing..."
        fi
    else
        log_message "WARN" ".env.template not found in S3, will skip"
    fi
    
    # Download Nginx configuration
    log_message "INFO" "Downloading Nginx configuration..."
    if aws s3 ls "s3://${S3_BUCKET}/nginx/nginx.conf" >/dev/null 2>&1; then
        if sudo aws s3 cp "s3://${S3_BUCKET}/nginx/nginx.conf" ./nginx.conf; then
            log_message "INFO" "✅ Downloaded nginx.conf successfully"
        else
            log_message "ERROR" "Failed to download nginx.conf"
            return 1
        fi
    else
        log_message "ERROR" "nginx.conf not found in S3 bucket"
        return 1
    fi
    
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
    
    # Ensure we can access the app directory
    if ! cd "$APP_DIR"; then
        log_message "ERROR" "Cannot access application directory: $APP_DIR"
        log_message "ERROR" "Directory check:"
        log_message "ERROR" "  - APP_DIR value: '${APP_DIR}'"
        log_message "ERROR" "  - Directory exists: $([ -d "$APP_DIR" ] && echo 'yes' || echo 'no')"
        log_message "ERROR" "  - Current directory: $(pwd)"
        log_message "ERROR" "  - Directory permissions: $(ls -ld "$APP_DIR" 2>/dev/null || echo 'cannot check')"
        return 1
    fi
    
    log_message "INFO" "Working in directory: $(pwd)"
    log_message "INFO" "Directory contents before .env creation:"
    ls -la 2>/dev/null || log_message "WARN" "Cannot list directory contents"
    
    # Backup existing .env if it exists
    if [ -f ".env" ]; then
        log_message "INFO" "Backing up existing .env file..."
        sudo cp .env .env.backup.$(date +%s) || {
            log_message "WARN" "Could not backup existing .env file, continuing..."
        }
    fi
    
    # Create temporary .env file first to test write permissions
    local temp_env_file="/tmp/.env.temp.$$"
    log_message "INFO" "Creating temporary environment file: $temp_env_file"
    
    # Create .env file content in temp location first
    if ! cat > "$temp_env_file" << EOF
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
    then
        log_message "ERROR" "Failed to create temporary environment file"
        log_message "ERROR" "Disk space check:"
        df -h /tmp || log_message "ERROR" "Cannot check /tmp disk space"
        return 1
    fi
    
    # Validate the temporary file was created correctly
    if [ ! -f "$temp_env_file" ]; then
        log_message "ERROR" "Temporary environment file was not created"
        return 1
    fi
    
    local line_count=$(wc -l < "$temp_env_file")
    log_message "INFO" "Temporary environment file created with $line_count lines"
    
    # Move the temporary file to the final location
    log_message "INFO" "Moving environment file to final location..."
    if ! sudo mv "$temp_env_file" ".env"; then
        log_message "ERROR" "Failed to move environment file to final location"
        log_message "ERROR" "Attempting alternative approach..."
        
        # Alternative: copy content directly
        if ! sudo cp "$temp_env_file" ".env"; then
            log_message "ERROR" "Failed to copy environment file to final location"
            log_message "ERROR" "Directory permissions:"
            ls -ld . || log_message "ERROR" "Cannot check current directory permissions"
            rm -f "$temp_env_file" 2>/dev/null || true
            return 1
        fi
    fi
    
    # Clean up temporary file
    rm -f "$temp_env_file" 2>/dev/null || true
    
    # Verify the final file exists
    if [ ! -f ".env" ]; then
        log_message "ERROR" "Environment file was not created successfully"
        return 1
    fi
    
    # Set secure permissions on .env file
    log_message "INFO" "Setting permissions on .env file..."
    if ! sudo chown ec2-user:ec2-user .env; then
        log_message "ERROR" "Failed to set ownership of .env file"
        log_message "ERROR" "Current file ownership: $(ls -l .env)"
        return 1
    fi
    
    if ! sudo chmod 600 .env; then
        log_message "ERROR" "Failed to set permissions on .env file"
        log_message "ERROR" "Current file permissions: $(ls -l .env)"
        return 1
    fi
    
    # Final validation
    local final_line_count=$(wc -l < .env)
    log_message "INFO" "✅ Environment file created successfully with $final_line_count variables"
    log_message "INFO" "✅ File permissions: $(ls -l .env)"
    
    # Show a sample of the file content (without sensitive data)
    log_message "INFO" "Environment file sample (showing first 10 lines):"
    head -10 .env | sed 's/=.*$/=***/' || log_message "WARN" "Cannot display file sample"
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
    
    # Ensure we're in the right directory
    if ! cd "$APP_DIR"; then
        log_message "ERROR" "Failed to change to application directory: $APP_DIR"
        return 1
    fi
    
    # Verify docker-compose.yml exists
    if [ ! -f "docker-compose.yml" ]; then
        log_message "ERROR" "docker-compose.yml not found in $APP_DIR"
        log_message "ERROR" "Available files: $(ls -la)"
        return 1
    fi
    
    # Verify .env file exists  
    if [ ! -f ".env" ]; then
        log_message "ERROR" ".env file not found in $APP_DIR"
        return 1
    fi
    
    # Test docker-compose configuration
    log_message "INFO" "Validating Docker Compose configuration..."
    if ! sudo docker-compose config >/dev/null 2>&1; then
        log_message "ERROR" "Invalid Docker Compose configuration"
        log_message "ERROR" "Compose config output:"
        sudo docker-compose config 2>&1 | head -20
        return 1
    fi
    
    # Start services with Docker Compose
    log_message "INFO" "Starting Docker Compose services..."
    if ! sudo docker-compose up -d; then
        log_message "ERROR" "Failed to start Docker Compose services"
        log_message "ERROR" "Docker Compose logs:"
        sudo docker-compose logs --tail=50
        return 1
    fi
    
    # Wait for services to start
    log_message "INFO" "Waiting for services to start (30 seconds)..."
    sleep 30
    
    # Check if containers are running
    log_message "INFO" "Checking container status..."
    local running_count=$(sudo docker-compose ps --services --filter "status=running" | wc -l)
    local total_count=$(sudo docker-compose ps --services | wc -l)
    
    log_message "INFO" "Containers running: $running_count/$total_count"
    
    if [ "$running_count" -eq 0 ]; then
        log_message "ERROR" "No containers are running"
        log_message "ERROR" "Container status:"
        sudo docker-compose ps
        log_message "ERROR" "Recent logs:"
        sudo docker-compose logs --tail=50
        return 1
    fi
    
    log_message "INFO" "✅ Services started successfully ($running_count/$total_count containers running)"
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

# Main execution with comprehensive error handling
main() {
    local step_count=0
    local total_steps=8
    
    log_message "INFO" "Starting redeployment process ($total_steps steps total)"
    
    # Step 1: Environment validation
    step_count=$((step_count + 1))
    log_message "INFO" "Step $step_count/$total_steps: Validating environment..."
    if ! validate_environment; then
        log_message "ERROR" "Environment validation failed - aborting redeployment"
        exit 1
    fi
    
    # Step 2: Backup current config
    step_count=$((step_count + 1))
    log_message "INFO" "Step $step_count/$total_steps: Backing up current configuration..."
    if ! backup_current_config; then
        log_message "ERROR" "Backup failed - aborting redeployment"
        exit 2
    fi
    
    # Step 3: Download fresh config
    step_count=$((step_count + 1))
    log_message "INFO" "Step $step_count/$total_steps: Downloading fresh configuration..."
    if ! download_fresh_config; then
        log_message "ERROR" "Configuration download failed - aborting redeployment"
        exit 3
    fi
    
    # Step 4: Create environment file
    step_count=$((step_count + 1))
    log_message "INFO" "Step $step_count/$total_steps: Creating environment file..."
    if ! create_environment_file; then
        log_message "ERROR" "Environment file creation failed - aborting redeployment"
        exit 4
    fi
    
    # Step 5: Stop existing services
    step_count=$((step_count + 1))
    log_message "INFO" "Step $step_count/$total_steps: Stopping existing services..."
    if ! stop_existing_services; then
        log_message "ERROR" "Failed to stop existing services - aborting redeployment"
        exit 5
    fi
    
    # Step 6: Pull latest images
    step_count=$((step_count + 1))
    log_message "INFO" "Step $step_count/$total_steps: Pulling latest images..."
    if ! pull_latest_images; then
        log_message "ERROR" "Image pull failed - aborting redeployment"
        exit 6
    fi
    
    # Step 7: Start services
    step_count=$((step_count + 1))
    log_message "INFO" "Step $step_count/$total_steps: Starting services..."
    if ! start_services; then
        log_message "ERROR" "Service startup failed - aborting redeployment"
        log_message "ERROR" "Attempting to show diagnostics..."
        cd "$APP_DIR" 2>/dev/null && {
            log_message "ERROR" "Current directory contents:"
            ls -la
            log_message "ERROR" "Docker status:"
            sudo docker ps -a
            log_message "ERROR" "Recent docker logs:"
            sudo docker-compose logs --tail=100 2>/dev/null || echo "No logs available"
        }
        exit 7
    fi
    
    # Step 8: Verify deployment
    step_count=$((step_count + 1))
    log_message "INFO" "Step $step_count/$total_steps: Verifying deployment..."
    if ! verify_deployment; then
        log_message "WARN" "Deployment verification had issues, but services appear to be running"
        log_message "WARN" "Check the service status manually: sudo docker-compose ps"
    fi
    
    # Cleanup (always run, even if verification fails)
    cleanup
    
    log_message "INFO" "🎉 SMS Seller Connect redeployment completed successfully!"
    log_message "INFO" "📋 Summary:"
    log_message "INFO" "  - Backup available at: $BACKUP_DIR" 
    log_message "INFO" "  - Application directory: $APP_DIR"
    log_message "INFO" "  - View logs: sudo docker-compose logs"
    log_message "INFO" "  - Check status: sudo docker-compose ps"
    log_message "INFO" "  - Application log file: $LOG_FILE"
    
    # Final status check
    cd "$APP_DIR" 2>/dev/null && {
        local final_running=$(sudo docker-compose ps --services --filter "status=running" | wc -l 2>/dev/null || echo "0")
        local final_total=$(sudo docker-compose ps --services | wc -l 2>/dev/null || echo "0")
        log_message "INFO" "  - Final container status: $final_running/$final_total running"
    }
    
    exit 0
}

# Error handling for script execution
set -e
set -o pipefail

# Run main function with all arguments
log_message "INFO" "🚀 Executing redeployment script with enhanced error handling..."
main "$@" 