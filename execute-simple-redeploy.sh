#!/bin/bash

# Simple EC2 Redeployment Script - Avoids SSM parameter parsing issues
# This script uses a simple SSM command to download and execute redeployment

set -e

# Configuration
REGION="us-east-1"
S3_BUCKET="sms-seller-connect-bucket"
PROJECT_NAME="sms-seller-connect"

echo "🚀 Executing simple redeployment on EC2 instance..."
echo "Region: $REGION"
echo "S3 Bucket: $S3_BUCKET"
echo ""

# Dynamically find the instance ID by tags
echo "🔍 Finding SMS Seller Connect EC2 instance..."
INSTANCE_ID=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters \
        "Name=tag:Name,Values=*sms-seller-connect*" \
        "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
    echo "❌ No running SMS Seller Connect instance found!"
    echo "🔍 Checking for any SMS-related instances..."
    
    # Try broader search
    aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=tag:Project,Values=SMSSellerConnect" \
        --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' \
        --output table
    
    echo ""
    echo "💡 Possible solutions:"
    echo "1. Check if the EC2 instance is running"
    echo "2. Verify the instance has the correct tags (Name: *sms-seller-connect*)"
    echo "3. Deploy infrastructure if no instance exists"
    exit 1
fi

echo "✅ Found instance: $INSTANCE_ID"
echo ""

# Simple SSM command that downloads and executes the redeployment script
# This avoids complex parameter parsing issues
echo "📤 Sending simple redeployment command via SSM..."

aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --region "$REGION" \
    --parameters 'commands=["#!/bin/bash","set -e","echo \"🚀 Starting redeployment process...\"","echo \"📥 Downloading redeployment script from S3...\"","aws s3 cp s3://sms-seller-connect-bucket/scripts/redeploy-application.sh /tmp/redeploy-application.sh","chmod +x /tmp/redeploy-application.sh","echo \"🔧 Executing redeployment script...\"","cd /app/sms-seller-connect || { echo \"❌ Application directory not found\"; exit 1; }","/tmp/redeploy-application.sh 2>&1 | tee /tmp/redeploy.log","REDEPLOY_EXIT_CODE=${PIPESTATUS[0]}","echo \"\"","echo \"📋 Redeployment completed with exit code: $REDEPLOY_EXIT_CODE\"","if [ $REDEPLOY_EXIT_CODE -eq 0 ]; then","  echo \"✅ Redeployment successful\"","else","  echo \"❌ Redeployment failed\"","  echo \"📜 Last 20 lines of redeploy log:\"","  tail -20 /tmp/redeploy.log || echo \"Cannot read redeploy log\"","fi","exit $REDEPLOY_EXIT_CODE"]' \
    --comment "Simple SMS Seller Connect Redeployment - $(date)" \
    --output table

echo ""
echo "✅ Simple redeployment command sent successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Monitor the command execution in AWS Systems Manager Console"
echo "2. Check the command output for success/failure status"
echo "3. If needed, check CloudWatch logs for detailed container logs"
echo ""
echo "🔗 AWS Systems Manager Console:"
echo "https://us-east-1.console.aws.amazon.com/systems-manager/run-command/history" 