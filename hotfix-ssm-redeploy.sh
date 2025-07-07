#!/bin/bash

echo "🔧 SMS SELLER CONNECT - HOTFIX SSM REDEPLOY"
echo "============================================"
echo ""

# Get region from environment or default
AWS_REGION=${AWS_REGION:-us-east-1}
ENVIRONMENT=${ENVIRONMENT:-prod}

echo "🔍 Finding instance..."
# Use the same method as the pipeline to find the instance
INSTANCE_ID=$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=sms-seller-connect-prod-ec2" \
           "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text 2>/dev/null)

if [ "$INSTANCE_ID" = "None" ] || [ "$INSTANCE_ID" = "null" ] || [ -z "$INSTANCE_ID" ]; then
  echo "⚠️  Cannot find instance by Name tag, using direct instance ID..."
  
  # Use the known instance ID from previous work
  INSTANCE_ID="i-0fb9053cc8b62ee2f"
  
  # Verify this instance exists and is running
  INSTANCE_STATE=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text 2>/dev/null)
  
  if [ "$INSTANCE_STATE" != "running" ]; then
    echo "❌ Instance $INSTANCE_ID is not running (state: $INSTANCE_STATE)"
    exit 1
  fi
fi

echo "✅ Found instance: $INSTANCE_ID"
echo ""

# Function to check SSM connectivity
check_ssm_connectivity() {
  echo "🔍 Testing SSM connectivity..."
  
  # Try simple SSM command
  if aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["echo \"SSM connectivity test\""]' \
    --query 'Command.CommandId' \
    --output text >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Function to restart instance to fix SSM
restart_instance_for_ssm() {
  echo "🔄 Restarting instance to restore SSM connectivity..."
  
  # Reboot instance (this will restart SSM agent and pick up new IAM permissions)
  aws ec2 reboot-instances --instance-ids "$INSTANCE_ID"
  
  echo "⏳ Waiting for instance to restart..."
  sleep 60
  
  # Wait for instance to be running
  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
  
  echo "⏳ Waiting for services to initialize (2 minutes)..."
  sleep 120
  
  echo "✅ Instance restart completed"
}

# Function to deploy via SSM
deploy_via_ssm() {
  echo "🚀 Deploying via SSM..."
  
  # Get latest commit SHA (if available)
  COMMIT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "latest")
  
  COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=[
      "#!/bin/bash",
      "set -e",
      "echo \"🚀 Starting hotfix redeployment...\"",
      "echo \"📥 Downloading redeployment script...\"",
      "aws s3 cp s3://sms-seller-connect-bucket/scripts/redeploy-application.sh /tmp/redeploy-application.sh",
      "chmod +x /tmp/redeploy-application.sh",
      "cd /app/sms-seller-connect || { echo \"❌ App directory not found\"; exit 1; }",
      "export BACKEND_IMAGE=\"522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-backend:'$COMMIT_SHA'\"",
      "export FRONTEND_IMAGE=\"522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-frontend:'$COMMIT_SHA'\"",
      "export SMS_API_DOMAIN=\"api.sms.typerelations.com\"",
      "export SMS_FRONTEND_DOMAIN=\"sms.typerelations.com\"",
      "export VITE_API_URL=\"https://api.sms.typerelations.com\"",
      "echo \"🔧 Executing redeployment with HTTPS fix...\"",
      "/tmp/redeploy-application.sh",
      "echo \"✅ Hotfix redeployment completed\""
    ]' \
    --comment "SMS Seller Connect Hotfix Redeployment" \
    --query 'Command.CommandId' \
    --output text)
  
  echo "📋 SSM Command ID: $COMMAND_ID"
  
  # Wait for command to complete
  echo "⏳ Waiting for deployment to complete..."
  aws ssm wait command-executed \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID"
  
  # Get command status and output
  STATUS=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query 'Status' \
    --output text)
  
  echo "📊 Deployment output:"
  aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query 'StandardOutputContent' \
    --output text
  
  if [ "$STATUS" = "Success" ]; then
    echo "✅ Deployment completed successfully!"
    return 0
  else
    echo "❌ Deployment failed with status: $STATUS"
    echo "Error output:"
    aws ssm get-command-invocation \
      --command-id "$COMMAND_ID" \
      --instance-id "$INSTANCE_ID" \
      --query 'StandardErrorContent' \
      --output text
    return 1
  fi
}

# Main execution flow
echo "🔧 Step 1: Check current SSM connectivity..."
if check_ssm_connectivity; then
  echo "✅ SSM is working - proceeding with deployment"
  
  if deploy_via_ssm; then
    echo "🎉 Hotfix deployment completed successfully!"
  else
    echo "❌ Deployment failed"
    exit 1
  fi
else
  echo "❌ SSM connectivity failed - restarting instance to fix"
  
  restart_instance_for_ssm
  
  echo "🔧 Step 2: Testing SSM connectivity after restart..."
  if check_ssm_connectivity; then
    echo "✅ SSM connectivity restored - proceeding with deployment"
    
    if deploy_via_ssm; then
      echo "🎉 Hotfix deployment completed successfully!"
    else
      echo "❌ Deployment failed after restart"
      exit 1
    fi
  else
    echo "❌ SSM connectivity still failed after restart"
    echo "🔍 This indicates a deeper issue. Please check:"
    echo "  1. IAM role has SSM permissions"
    echo "  2. SSM agent is installed and running"
    echo "  3. Instance has internet connectivity"
    exit 1
  fi
fi

echo ""
echo "🎯 HOTFIX COMPLETED!"
echo "Frontend URL: https://sms.typerelations.com"
echo "API URL: https://api.sms.typerelations.com"
echo ""
echo "The mixed content error should now be resolved!" 