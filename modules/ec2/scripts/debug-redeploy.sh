#!/bin/bash

# SMS Seller Connect Debug Script
# This script helps diagnose redeployment issues

set -e

LOG_FILE="/var/log/debug-redeploy.log"
APP_DIR="/app/sms-seller-connect"

# Create log file if it doesn't exist
sudo touch "$LOG_FILE"
sudo chmod 666 "$LOG_FILE"

# Logging function
log_debug() {
    local message="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    echo "[$timestamp] [DEBUG] $message" | tee -a "$LOG_FILE"
}

echo "🔍 SMS Seller Connect Redeploy Debug Report"
echo "=========================================="
echo "Generated: $(date)"
echo ""

log_debug "Starting debug report generation"

# System Information
echo "📋 SYSTEM INFORMATION"
echo "-------------------"
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime)"
echo "User: $(whoami)"
echo ""

# Disk Space
echo "💾 DISK SPACE"
echo "------------"
df -h
echo ""

# Memory Usage
echo "🧠 MEMORY USAGE"
echo "--------------"
free -h
echo ""

# Docker Status
echo "🐳 DOCKER STATUS"
echo "---------------"
echo "Docker version: $(docker --version 2>/dev/null || echo 'NOT INSTALLED')"
echo "Docker service: $(sudo systemctl is-active docker 2>/dev/null || echo 'INACTIVE')"
echo "Docker daemon: $(sudo docker info >/dev/null 2>&1 && echo 'RUNNING' || echo 'NOT RUNNING')"
echo ""

if sudo docker info >/dev/null 2>&1; then
    echo "Docker containers:"
    sudo docker ps -a
    echo ""
    
    echo "Docker images:"
    sudo docker images | head -10
    echo ""
    
    echo "Docker networks:"
    sudo docker network ls
    echo ""
fi

# AWS CLI Status
echo "☁️ AWS CLI STATUS"
echo "----------------"
echo "AWS CLI version: $(aws --version 2>/dev/null || echo 'NOT INSTALLED')"
echo "AWS credentials: $(aws sts get-caller-identity >/dev/null 2>&1 && echo 'VALID' || echo 'INVALID')"
echo "AWS region: ${AWS_REGION:-NOT SET}"
echo ""

# Environment Variables
echo "🌍 ENVIRONMENT VARIABLES"
echo "-----------------------"
echo "Key environment variables:"

ENV_VARS=(
    "BACKEND_IMAGE"
    "FRONTEND_IMAGE"
    "SMS_API_DOMAIN"
    "SMS_FRONTEND_DOMAIN"
    "AWS_REGION"
    "S3_BUCKET"
    "DB_HOST"
    "DB_USER"
    "TWILIO_ACCOUNT_SID"
    "OPENAI_API_KEY"
    "SECRET_KEY"
)

for var in "${ENV_VARS[@]}"; do
    value="${!var}"
    if [ -n "$value" ]; then
        # Show only first 20 chars for security
        echo "  ✅ $var: ${value:0:20}..."
    else
        echo "  ❌ $var: NOT SET"
    fi
done
echo ""

# Application Directory
echo "📁 APPLICATION DIRECTORY"
echo "-----------------------"
if [ -d "$APP_DIR" ]; then
    echo "Application directory exists: $APP_DIR"
    echo "Contents:"
    ls -la "$APP_DIR"
    echo ""
    
    if [ -f "$APP_DIR/docker-compose.yml" ]; then
        echo "Docker Compose file exists"
        echo "Services defined:"
        grep -E "^  [a-zA-Z]" "$APP_DIR/docker-compose.yml" | sed 's/://g' | sed 's/^  /    - /' || echo "    Cannot parse services"
        echo ""
    else
        echo "❌ docker-compose.yml NOT FOUND"
    fi
    
    if [ -f "$APP_DIR/.env" ]; then
        echo ".env file exists ($(wc -l < "$APP_DIR/.env") lines)"
    else
        echo "❌ .env file NOT FOUND"
    fi
    echo ""
else
    echo "❌ Application directory does not exist: $APP_DIR"
    echo ""
fi

# Docker Compose Status
echo "🐳 DOCKER COMPOSE STATUS"
echo "-----------------------"
if [ -d "$APP_DIR" ] && [ -f "$APP_DIR/docker-compose.yml" ]; then
    cd "$APP_DIR"
    
    echo "Docker Compose configuration validation:"
    if sudo docker-compose config >/dev/null 2>&1; then
        echo "  ✅ Configuration is valid"
    else
        echo "  ❌ Configuration is invalid:"
        sudo docker-compose config 2>&1 | head -10
    fi
    echo ""
    
    echo "Container status:"
    sudo docker-compose ps 2>/dev/null || echo "  ❌ Cannot get container status"
    echo ""
    
    echo "Recent logs (last 20 lines):"
    sudo docker-compose logs --tail=20 2>/dev/null || echo "  ❌ Cannot get logs"
    echo ""
else
    echo "❌ Cannot check Docker Compose status - missing files"
    echo ""
fi

# Network Connectivity
echo "🌐 NETWORK CONNECTIVITY"
echo "----------------------"
echo "Internet connectivity:"
echo "  Google DNS: $(ping -c1 8.8.8.8 >/dev/null 2>&1 && echo '✅ OK' || echo '❌ FAILED')"
echo "  GitHub: $(ping -c1 github.com >/dev/null 2>&1 && echo '✅ OK' || echo '❌ FAILED')"
echo "  AWS S3: $(ping -c1 s3.amazonaws.com >/dev/null 2>&1 && echo '✅ OK' || echo '❌ FAILED')"
echo ""

# S3 Bucket Access
echo "🪣 S3 BUCKET ACCESS"
echo "------------------"
if [ -n "${S3_BUCKET}" ]; then
    echo "S3 bucket: ${S3_BUCKET}"
    echo "Bucket access: $(aws s3 ls "s3://${S3_BUCKET}/" >/dev/null 2>&1 && echo '✅ OK' || echo '❌ FAILED')"
    
    if aws s3 ls "s3://${S3_BUCKET}/" >/dev/null 2>&1; then
        echo "Bucket contents:"
        aws s3 ls "s3://${S3_BUCKET}/" --recursive | head -10
    fi
else
    echo "❌ S3_BUCKET environment variable not set"
fi
echo ""

# Health Endpoints
echo "🏥 HEALTH ENDPOINTS"
echo "------------------"
ENDPOINTS=(
    "localhost:80/alb-health"
    "localhost:8900/health"
    "localhost:8082"
)

for endpoint in "${ENDPOINTS[@]}"; do
    echo -n "  $endpoint: "
    if curl -f -s --max-time 5 "http://$endpoint" >/dev/null 2>&1; then
        echo "✅ RESPONDING"
    else
        echo "❌ NOT RESPONDING"
    fi
done
echo ""

# Recent Logs
echo "📜 RECENT SYSTEM LOGS"
echo "-------------------"
echo "Last 10 system messages:"
sudo journalctl --no-pager --lines=10 --since="1 hour ago" | tail -10
echo ""

echo "Last 10 Docker service logs:"
sudo journalctl -u docker --no-pager --lines=10 --since="1 hour ago" | tail -10
echo ""

# File Permissions
echo "🔐 FILE PERMISSIONS"
echo "------------------"
if [ -d "$APP_DIR" ]; then
    echo "Application directory permissions:"
    ls -ld "$APP_DIR"
    
    echo "Key file permissions:"
    cd "$APP_DIR"
    for file in docker-compose.yml .env nginx.conf *.sh; do
        if [ -f "$file" ]; then
            echo "  $(ls -l "$file")"
        fi
    done
else
    echo "❌ Cannot check file permissions - application directory missing"
fi
echo ""

# Process Information
echo "⚙️ RUNNING PROCESSES"
echo "-------------------"
echo "Docker processes:"
ps aux | grep -E "(docker|containerd)" | grep -v grep | head -5
echo ""

echo "Application-related processes:"
ps aux | grep -E "(sms|seller|connect)" | grep -v grep | head -5
echo ""

log_debug "Debug report generation completed"

echo "🔍 DEBUG REPORT COMPLETE"
echo "======================"
echo "Log file: $LOG_FILE"
echo "For additional help, check:"
echo "  - Application logs: sudo docker-compose logs"
echo "  - System logs: sudo journalctl -u docker"
echo "  - Container status: sudo docker ps -a"
echo ""
echo "If redeployment is still failing, run this script again after attempting redeploy"
echo "to see what changed." 