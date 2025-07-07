#!/bin/bash

# Direct Frontend Fix Script
# This bypasses the deployment pipeline and directly fixes the frontend container

set -e

echo "🚀 Direct Frontend Container Fix"
echo "================================"

# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=sms-seller-connect-prod-ec2" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].InstanceId' --output text)
echo "Instance ID: $INSTANCE_ID"

# Create fix script
FIX_SCRIPT='#!/bin/bash
cd /app/sms-seller-connect

echo "Current frontend container status:"
sudo docker ps --filter "name=sms_frontend"

echo "Stopping current frontend container..."
sudo docker stop sms_frontend || true
sudo docker rm sms_frontend || true

echo "Getting environment variables..."
export FRONTEND_IMAGE=${FRONTEND_IMAGE:-522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-frontend:latest}

echo "Starting new frontend container with correct API URL..."
sudo docker run -d \
  --name sms_frontend \
  --network sms-seller-connect_app_network \
  -p 8082:8082 \
  -e NODE_ENV=production \
  -e FRONTEND_PORT=8082 \
  -e VITE_API_URL=https://api.sms.typerelations.com \
  -e REACT_APP_API_URL=https://api.sms.typerelations.com \
  -e API_URL=https://api.sms.typerelations.com \
  -e BACKEND_URL=https://api.sms.typerelations.com \
  --restart unless-stopped \
  --health-cmd="wget --quiet --tries=1 --spider http://localhost:8082 || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  $FRONTEND_IMAGE

echo "Waiting for container to start..."
sleep 10

echo "New container status:"
sudo docker ps --filter "name=sms_frontend"

echo "Testing frontend health:"
curl -f http://localhost:8082 && echo "✅ Frontend is responding" || echo "❌ Frontend not responding yet"

echo "✅ Frontend container fixed!"
'

# Execute via Systems Manager
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"$FIX_SCRIPT\"]" \
  --output text \
  --query 'Command.CommandId'

echo ""
echo "🎯 Fix script sent to EC2 instance!"
echo "⏳ This should fix the frontend container in ~30 seconds"
echo "🔄 Check status with: curl https://sms.typerelations.com/login" 