#!/bin/bash
set -e

# Enhanced logging for CloudWatch
log_to_cloudwatch() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    echo "[$timestamp] [$level] EC2-UserData: $message"
    
    # Also log to CloudWatch logs file for agent pickup
    if [ ! -z "${CLOUDWATCH_LOG_GROUP}" ]; then
        echo "[$timestamp] [$level] EC2-UserData: $message" >> /var/log/sms-seller-connect-setup.log 2>/dev/null || true
    fi
}

# Error handling
handle_error() {
    log_to_cloudwatch "ERROR" "Error occurred in function: $1 on line $2"
    exit 1
}

trap 'handle_error "$FUNCNAME" "$LINENO"' ERR

# Function to install CloudWatch Agent
install_cloudwatch_agent() {
    log_to_cloudwatch "INFO" "Installing CloudWatch Agent..."
    
    # Download and install CloudWatch agent
    wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
    sudo rpm -U ./amazon-cloudwatch-agent.rpm
    
    # Create CloudWatch agent configuration
    cat << 'EOF' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/sms-seller-connect-setup.log",
                        "log_group_name": "/aws/ec2/sms-seller-connect",
                        "log_stream_name": "ec2-setup-{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/sms-seller-connect-app.log",
                        "log_group_name": "/aws/ec2/sms-seller-connect",
                        "log_stream_name": "application-{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/docker",
                        "log_group_name": "/aws/ec2/sms-seller-connect",
                        "log_stream_name": "docker-{instance_id}",
                        "timezone": "UTC"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "SMSSellerConnect/EC2",
        "metrics_collected": {
            "cpu": {
                "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": ["used_percent"],
                "metrics_collection_interval": 60,
                "resources": ["*"]
            },
            "mem": {
                "measurement": ["mem_used_percent"],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF
    
    # Start CloudWatch agent
    sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
        -a fetch-config \
        -m ec2 \
        -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
        -s
    
    log_to_cloudwatch "INFO" "CloudWatch Agent installation completed"
}

# Function to install SSM Agent
install_ssm_agent() {
    log_to_cloudwatch "INFO" "Starting SSM Agent installation..."
    sudo yum update -y
    sudo yum install -y amazon-ssm-agent
    sudo systemctl enable amazon-ssm-agent
    sudo systemctl start amazon-ssm-agent
    log_to_cloudwatch "INFO" "SSM Agent installation completed"
}

# Function to install Docker and Docker Compose
install_docker() {
    log_to_cloudwatch "INFO" "Starting Docker installation..."
    sudo yum update -y
    sudo yum install -y docker gettext-devel  # gettext-devel provides envsubst
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -a -G docker ec2-user
    
    # Configure Docker daemon for better logging
    sudo mkdir -p /etc/docker
    cat << 'EOF' > /etc/docker/daemon.json
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF
    
    sudo systemctl restart docker
    
    # Install Docker Compose
    log_to_cloudwatch "INFO" "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log_to_cloudwatch "INFO" "Docker and Docker Compose installation completed"
}

# Function to install AWS CLI and required tools
install_aws_cli() {
    log_to_cloudwatch "INFO" "Installing AWS CLI and required tools..."
    sudo yum install -y aws-cli gettext
    log_to_cloudwatch "INFO" "AWS CLI and tools installation completed"
}

# Function to verify environment variables
verify_env_variables() {
    log_to_cloudwatch "INFO" "Checking environment variables..."
    if [ -z "${AWS_REGION}" ]; then
        log_to_cloudwatch "ERROR" "AWS_REGION environment variable is not set."
        exit 1
    fi
    log_to_cloudwatch "INFO" "Environment variables verified"
}

# Function to setup ECR login
setup_ecr() {
    log_to_cloudwatch "INFO" "Logging into Amazon ECR..."
    ECR_REGISTRY="522814698925.dkr.ecr.us-east-1.amazonaws.com"
    sudo aws ecr get-login-password --region "${AWS_REGION}" | sudo docker login --username AWS --password-stdin "$ECR_REGISTRY"
    log_to_cloudwatch "INFO" "ECR login completed"
}

# Function to create log directories
setup_log_directories() {
    log_to_cloudwatch "INFO" "Setting up log directories..."
    sudo mkdir -p /var/log
    sudo mkdir -p /app/logs
    sudo touch /var/log/sms-seller-connect-setup.log
    sudo touch /var/log/sms-seller-connect-app.log
    sudo chown -R ec2-user:ec2-user /var/log/sms-seller-connect-*.log
    sudo chown -R ec2-user:ec2-user /app/logs
    log_to_cloudwatch "INFO" "Log directories setup completed"
}

# Function to copy and configure Docker Compose files
setup_docker_compose() {
    log_to_cloudwatch "INFO" "Setting up Docker Compose configuration..."
    
    # Create application directory
    sudo mkdir -p /app/sms-seller-connect
    cd /app/sms-seller-connect
    
    # Copy Docker Compose file from S3 (uploaded by Terraform)
    log_to_cloudwatch "INFO" "Downloading Docker Compose configuration from S3..."
    sudo aws s3 cp s3://${S3_BUCKET}/docker-compose/docker-compose.yml ./docker-compose.yml
    sudo aws s3 cp s3://${S3_BUCKET}/docker-compose/.env.template ./.env.template
    sudo aws s3 cp s3://${S3_BUCKET}/nginx/nginx.conf ./nginx.conf.template
    sudo aws s3 cp s3://${S3_BUCKET}/scripts/health-check.sh ./health-check.sh
    sudo aws s3 cp s3://${S3_BUCKET}/scripts/health-check-server.py ./health-check-server.py
    
    # Export environment variables for envsubst
    export BACKEND_IMAGE="${BACKEND_IMAGE}"
    export FRONTEND_IMAGE="${FRONTEND_IMAGE}"
    export SMS_API_DOMAIN="${SMS_API_DOMAIN}"
    export SMS_FRONTEND_DOMAIN="${SMS_FRONTEND_DOMAIN}"
    export DB_HOST="${DB_HOST}"
    export DB_PORT="${DB_PORT}"
    export DB_NAME="${DB_NAME}"
    export DB_USER="${DB_USER}"
    export DB_PASSWORD="${DB_PASSWORD}"
    export TWILIO_ACCOUNT_SID="${TWILIO_ACCOUNT_SID}"
    export TWILIO_AUTH_TOKEN="${TWILIO_AUTH_TOKEN}"
    export TWILIO_PHONE_NUMBER="${TWILIO_PHONE_NUMBER}"
    export OPENAI_API_KEY="${OPENAI_API_KEY}"
    export OPENAI_MODEL="${OPENAI_MODEL}"
    export OPENAI_TEMPERATURE="${OPENAI_TEMPERATURE}"
    export FLASK_SECRET_KEY="${SECRET_KEY}"
    export SECRET_KEY="${SECRET_KEY}"
    export JWT_SECRET_KEY="${JWT_SECRET_KEY}"
    export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
    export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
    export AWS_REGION="${AWS_REGION}"
    export S3_BUCKET_NAME="${S3_BUCKET_NAME}"
    export SENDGRID_API_KEY="${SENDGRID_API_KEY}"
    export SENDGRID_FROM_EMAIL="${SENDGRID_FROM_EMAIL}"
    export HOT_LEAD_EMAIL_RECIPIENTS="${HOT_LEAD_EMAIL_RECIPIENTS}"
    export HOT_LEAD_SMS_RECIPIENTS="${HOT_LEAD_SMS_RECIPIENTS}"
    export RATE_LIMIT_PER_MINUTE="${RATE_LIMIT_PER_MINUTE}"
    export RATE_LIMIT_BURST="${RATE_LIMIT_BURST}"
    export SESSION_TIMEOUT_MINUTES="${SESSION_TIMEOUT_MINUTES}"
    export REMEMBER_ME_DAYS="${REMEMBER_ME_DAYS}"
    export MAX_FILE_SIZE_MB="${MAX_FILE_SIZE_MB}"
    export ALLOWED_FILE_TYPES="${ALLOWED_FILE_TYPES}"
    export CLOUDWATCH_LOG_GROUP="${CLOUDWATCH_LOG_GROUP}"
    export CLOUDWATCH_LOG_STREAM="${CLOUDWATCH_LOG_STREAM}"
    
    # Create environment file from template with actual values
    log_to_cloudwatch "INFO" "Creating environment file with configuration..."
    envsubst < .env.template > .env
    
    # CRITICAL: Substitute variables in nginx configuration
    log_to_cloudwatch "INFO" "Substituting variables in nginx configuration..."
    envsubst '${SMS_API_DOMAIN} ${SMS_FRONTEND_DOMAIN}' < nginx.conf.template > nginx.conf
    
    # Set proper permissions
    sudo chown -R ec2-user:ec2-user /app/sms-seller-connect
    sudo chmod 600 .env  # Secure the environment file
    sudo chmod 644 docker-compose.yml
    sudo chmod 644 nginx.conf
    sudo chmod 755 health-check.sh
    sudo chmod 644 health-check-server.py
    
    log_to_cloudwatch "INFO" "Docker Compose configuration setup completed"
}

# Function to pull images and start services
start_services() {
    log_to_cloudwatch "INFO" "Starting SMS Seller Connect services..."
    
    cd /app/sms-seller-connect
    
    # Debug: Log the image variables before creating .env file
    log_to_cloudwatch "INFO" "DEBUG: BACKEND_IMAGE=${BACKEND_IMAGE}"
    log_to_cloudwatch "INFO" "DEBUG: FRONTEND_IMAGE=${FRONTEND_IMAGE}"
    log_to_cloudwatch "INFO" "DEBUG: SMS_API_DOMAIN=${SMS_API_DOMAIN}"
    log_to_cloudwatch "INFO" "DEBUG: SMS_FRONTEND_DOMAIN=${SMS_FRONTEND_DOMAIN}"
    
    # Set fallback values if variables are empty
    # Note: These should normally be set by Terraform with commit-specific tags
    if [ -z "${BACKEND_IMAGE}" ]; then
        # Try to get the latest tag from ECR instead of using :latest
        LATEST_TAG=$(aws ecr describe-images --repository-name sms-wholesaling-backend \
          --region us-east-1 --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' \
          --output text 2>/dev/null || echo "latest")
        BACKEND_IMAGE="522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-backend:${LATEST_TAG}"
        log_to_cloudwatch "WARN" "BACKEND_IMAGE was empty, using latest available tag: ${BACKEND_IMAGE}"
    fi
    
    if [ -z "${FRONTEND_IMAGE}" ]; then
        # Try to get the latest tag from ECR instead of using :latest
        LATEST_TAG=$(aws ecr describe-images --repository-name sms-wholesaling-frontend \
          --region us-east-1 --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' \
          --output text 2>/dev/null || echo "latest")
        FRONTEND_IMAGE="522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-frontend:${LATEST_TAG}"
        log_to_cloudwatch "WARN" "FRONTEND_IMAGE was empty, using latest available tag: ${FRONTEND_IMAGE}"
    fi
    
    # Create .env file for Docker Compose with all variables
    log_to_cloudwatch "INFO" "Creating .env file for Docker Compose..."
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
    
    # Pull latest images
    log_to_cloudwatch "INFO" "Pulling latest images from ECR..."
    sudo -E docker-compose pull
    
    # Start services
    log_to_cloudwatch "INFO" "Starting services with Docker Compose..."
    sudo -E docker-compose up -d
    
    log_to_cloudwatch "INFO" "Services started successfully"
}

# Function to verify setup
verify_setup() {
    log_to_cloudwatch "INFO" "Verifying setup..."
    
    cd /app/sms-seller-connect
    
    # Check if containers are running
    if sudo docker-compose ps | grep -q "Up"; then
        log_to_cloudwatch "INFO" "✅ Docker containers are running"
    else
        log_to_cloudwatch "ERROR" "❌ Docker containers are not running"
        sudo docker-compose logs
        exit 1
    fi
    
    # Check CloudWatch agent status
    if sudo systemctl is-active --quiet amazon-cloudwatch-agent; then
        log_to_cloudwatch "INFO" "✅ CloudWatch Agent is running"
    else
        log_to_cloudwatch "WARN" "⚠️ CloudWatch Agent is not running"
    fi
    
    # Check application health (give it time to start)
    log_to_cloudwatch "INFO" "Waiting for applications to start..."
    sleep 60
    
    # Check backend health
    if curl -f http://localhost:8900/health > /dev/null 2>&1; then
        log_to_cloudwatch "INFO" "✅ Backend health check passed"
    else
        log_to_cloudwatch "WARN" "⚠️ Backend health check failed - may still be starting"
    fi
    
    # Check frontend health
    if curl -f http://localhost:8082 > /dev/null 2>&1; then
        log_to_cloudwatch "INFO" "✅ Frontend health check passed"
    else
        log_to_cloudwatch "WARN" "⚠️ Frontend health check failed - may still be starting"
    fi
    
    log_to_cloudwatch "INFO" "Setup verification completed"
}

# Function to setup monitoring and maintenance
setup_monitoring() {
    log_to_cloudwatch "INFO" "Setting up monitoring and maintenance..."
    
    # Copy maintenance script from S3
    sudo aws s3 cp s3://${S3_BUCKET}/scripts/maintenance.sh /app/sms-seller-connect/maintenance.sh
    chmod +x /app/sms-seller-connect/maintenance.sh
    
    # Create symlink for easy access
    sudo ln -sf /app/sms-seller-connect/maintenance.sh /usr/local/bin/sms-maintenance
    
    # Add cron job for health checks (every 5 minutes)
    echo "*/5 * * * * /app/sms-seller-connect/maintenance.sh check" | sudo crontab -u root -
    
    # Add daily update check (at 2 AM)
    (sudo crontab -u root -l 2>/dev/null; echo "0 2 * * * /app/sms-seller-connect/maintenance.sh update") | sudo crontab -u root -
    
    # Create log rotation for maintenance logs
    cat << 'EOF' | sudo tee /etc/logrotate.d/sms-seller-connect
/var/log/sms-seller-connect-maintenance.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF
    
    log_to_cloudwatch "INFO" "Monitoring and maintenance setup completed"
}

# Main execution
main() {
    # Create a lock file to prevent multiple executions
    LOCK_FILE="/var/lock/user_data.lock"
    if [ -f "$LOCK_FILE" ]; then
        log_to_cloudwatch "INFO" "Setup already running or completed. If you need to run again, remove $LOCK_FILE"
        exit 0
    fi
    touch "$LOCK_FILE"
    
    log_to_cloudwatch "INFO" "=== Starting SMS Seller Connect EC2 Setup ==="
    log_to_cloudwatch "INFO" "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
    log_to_cloudwatch "INFO" "AWS Region: ${AWS_REGION}"
    
    setup_log_directories
    install_ssm_agent
    install_cloudwatch_agent
    install_docker
    install_aws_cli
    verify_env_variables
    setup_ecr
    setup_docker_compose
    start_services
    setup_monitoring
    verify_setup
    
    log_to_cloudwatch "INFO" "🎉 SMS Seller Connect setup completed successfully at $(date)"
    echo "Setup completed successfully at $(date)" >> "$LOCK_FILE"
}

# Run main functions
main
