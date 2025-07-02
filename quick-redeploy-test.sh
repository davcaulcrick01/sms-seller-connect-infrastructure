#!/bin/bash

# Quick redeploy test script to diagnose and fix the exit code 252 issue
# This script manually runs the redeploy with enhanced debugging

set -e

echo "🔧 QUICK REDEPLOY TEST - Debugging Exit Code 252"
echo "=================================================="
echo ""

# Get EC2 instance details
echo "🔍 Getting EC2 instance details..."
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=sms-seller-connect-prod-ec2" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

if [ "$INSTANCE_ID" = "None" ] || [ "$INSTANCE_ID" = "null" ]; then
  echo "❌ No running EC2 instance found"
  exit 1
fi

INSTANCE_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "✅ Found EC2 instance:"
echo "  Instance ID: $INSTANCE_ID"
echo "  Public IP: $INSTANCE_IP"

# Create enhanced redeploy command with detailed debugging
echo ""
echo "🚀 Executing enhanced redeploy with debugging..."

REDEPLOY_COMMAND=$(cat << 'EOF'
#!/bin/bash
set -e

# Set up comprehensive logging
LOG_FILE="/tmp/enhanced-redeploy-debug.log"
exec 2> >(tee -a "$LOG_FILE" >&2)
exec 1> >(tee -a "$LOG_FILE")

echo "=== ENHANCED REDEPLOY DEBUG SESSION ==="
echo "Timestamp: $(date)"
echo "User: $(whoami)"
echo "Working Directory: $(pwd)"
echo ""

# Enhanced environment debugging
echo "🔍 ENVIRONMENT DEBUGGING:"
echo "========================="
echo "Environment variables with SMS_, BACKEND_, FRONTEND_, DB_:"
printenv | grep -E "(SMS_|BACKEND_|FRONTEND_|DB_|AWS_|TWILIO_|OPENAI_|SECRET_)" | sort || echo "No matching environment variables found"

echo ""
echo "Critical variables check:"
echo "BACKEND_IMAGE: '${BACKEND_IMAGE:-NOT SET}'"
echo "FRONTEND_IMAGE: '${FRONTEND_IMAGE:-NOT SET}'"
echo "SMS_API_DOMAIN: '${SMS_API_DOMAIN:-NOT SET}'"
echo "SMS_FRONTEND_DOMAIN: '${SMS_FRONTEND_DOMAIN:-NOT SET}'"
echo "AWS_REGION: '${AWS_REGION:-NOT SET}'"
echo "S3_BUCKET: '${S3_BUCKET:-NOT SET}'"

echo ""
echo "🔍 SYSTEM STATE DEBUGGING:"
echo "=========================="
echo "Disk space:"
df -h

echo ""
echo "Docker status:"
sudo systemctl status docker --no-pager || echo "Cannot check Docker status"

echo ""
echo "Current application directory:"
if [ -d "/app/sms-seller-connect" ]; then
    echo "Directory exists: /app/sms-seller-connect"
    ls -la /app/sms-seller-connect/ || echo "Cannot list directory"
    echo "Directory permissions: $(ls -ld /app/sms-seller-connect/)"
else
    echo "Directory does not exist: /app/sms-seller-connect"
    echo "Creating directory..."
    sudo mkdir -p /app/sms-seller-connect
    sudo chown ec2-user:ec2-user /app/sms-seller-connect
fi

echo ""
echo "📥 Downloading enhanced redeploy script..."
aws s3 cp s3://sms-seller-connect-bucket/scripts/redeploy-application.sh /tmp/redeploy-application-enhanced.sh
chmod +x /tmp/redeploy-application-enhanced.sh

echo ""
echo "🚀 Executing enhanced redeploy script..."
echo "========================================"

# Export all environment variables to ensure they're available
export BACKEND_IMAGE="${BACKEND_IMAGE}"
export FRONTEND_IMAGE="${FRONTEND_IMAGE}"
export SMS_API_DOMAIN="${SMS_API_DOMAIN}"
export SMS_FRONTEND_DOMAIN="${SMS_FRONTEND_DOMAIN}"
export AWS_REGION="${AWS_REGION}"
export S3_BUCKET="${S3_BUCKET:-sms-seller-connect-bucket}"
export DB_HOST="${DB_HOST}"
export DB_PORT="${DB_PORT}"
export DB_NAME="${DB_NAME}"
export DB_USER="${DB_USER}"
export DB_PASSWORD="${DB_PASSWORD}"
export TWILIO_ACCOUNT_SID="${TWILIO_ACCOUNT_SID}"
export TWILIO_AUTH_TOKEN="${TWILIO_AUTH_TOKEN}"
export TWILIO_PHONE_NUMBER="${TWILIO_PHONE_NUMBER}"
export OPENAI_API_KEY="${OPENAI_API_KEY}"
export SECRET_KEY="${FLASK_SECRET_KEY}"
export JWT_SECRET_KEY="${JWT_SECRET_KEY}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"

if /tmp/redeploy-application-enhanced.sh; then
    echo ""
    echo "✅ REDEPLOY COMPLETED SUCCESSFULLY!"
    echo "==================================="
    
    echo "Final container status:"
    cd /app/sms-seller-connect 2>/dev/null && sudo docker-compose ps || echo "Cannot check container status"
    
    echo ""
    echo "Health check:"
    curl -f http://localhost:8900/health && echo " ✅ Backend healthy" || echo " ❌ Backend not responding"
    curl -f http://localhost:80/alb-health && echo " ✅ ALB health endpoint healthy" || echo " ❌ ALB health not responding"
    
else
    EXIT_CODE=$?
    echo ""
    echo "❌ REDEPLOY FAILED WITH EXIT CODE: $EXIT_CODE"
    echo "=============================================="
    
    # Enhanced failure diagnostics
    echo "System state after failure:"
    echo "Docker containers:"
    sudo docker ps -a 2>/dev/null || echo "Cannot check Docker containers"
    
    echo ""
    echo "Recent system logs:"
    sudo journalctl --no-pager --lines=50 --since="5 minutes ago" || echo "Cannot access system logs"
    
    echo ""
    echo "Application logs:"
    if [ -f "/var/log/redeploy-application.log" ]; then
        echo "Last 50 lines of redeploy log:"
        tail -50 /var/log/redeploy-application.log
    fi
    
    if [ -f "/tmp/enhanced-redeploy-debug.log" ]; then
        echo ""
        echo "Enhanced debug log:"
        tail -100 /tmp/enhanced-redeploy-debug.log
    fi
    
    exit $EXIT_CODE
fi
EOF
)

echo "📡 Executing command via SSM..."
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"$REDEPLOY_COMMAND\"]" \
  --output text \
  --query 'Command.CommandId' > /tmp/ssm-command-id.txt

COMMAND_ID=$(cat /tmp/ssm-command-id.txt)
echo "✅ SSM Command sent with ID: $COMMAND_ID"

echo ""
echo "⏳ Waiting for command execution (this may take a few minutes)..."
echo "You can monitor progress at: https://console.aws.amazon.com/systems-manager/run-command/executing-commands"

# Wait for command completion
MAX_WAIT=600  # 10 minutes
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS=$(aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --query 'Status' \
        --output text 2>/dev/null || echo "InProgress")
    
    case $STATUS in
        "Success")
            echo ""
            echo "✅ Command completed successfully!"
            break
            ;;
        "Failed")
            echo ""
            echo "❌ Command failed!"
            break
            ;;
        "InProgress")
            echo -n "."
            sleep 10
            ELAPSED=$((ELAPSED + 10))
            ;;
        *)
            echo -n "?"
            sleep 10
            ELAPSED=$((ELAPSED + 10))
            ;;
    esac
done

echo ""
echo "📋 Getting command output..."
aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query 'StandardOutputContent' \
    --output text

if [ "$STATUS" = "Failed" ]; then
    echo ""
    echo "❌ Error output:"
    aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --query 'StandardErrorContent' \
        --output text
fi

echo ""
echo "🏁 Quick redeploy test completed!"
echo "Status: $STATUS" 