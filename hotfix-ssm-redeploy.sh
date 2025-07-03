#!/bin/bash

# Hotfix: Fix SSM Parameter Parsing Issue in Terraform Pipeline
# This script fixes the JSON parsing error in the redeploy job

set -e

echo "🚀 Applying hotfix for SSM parameter parsing issue..."
echo "=================================================="

WORKFLOW_FILE=".github/workflows/terraform.yml"

# Check if the workflow file exists
if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "❌ Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

echo "📝 Backing up original workflow file..."
cp "$WORKFLOW_FILE" "${WORKFLOW_FILE}.backup-$(date +%Y%m%d-%H%M%S)"

echo "🔧 Applying SSM parameter parsing fix..."

# Use sed to replace the problematic SSM command with a fixed version
sed -i '' '/# Execute the command via SSM/,/--output text)/c\
        # Execute the command via SSM (Fixed - using simple S3 download approach)\
        COMMAND_ID=$(aws ssm send-command \\\
          --instance-ids "${{ steps.ec2-details.outputs.instance_id }}" \\\
          --document-name "AWS-RunShellScript" \\\
          --parameters '"'"'commands=["#!/bin/bash","set -e","echo \"🚀 Starting redeployment process...\"","echo \"📥 Downloading redeployment script from S3...\"","aws s3 cp s3://sms-seller-connect-bucket/scripts/redeploy-application.sh /tmp/redeploy-application.sh","chmod +x /tmp/redeploy-application.sh","echo \"🔧 Executing redeployment script...\"","cd /app/sms-seller-connect || { echo \"❌ Application directory not found\"; exit 1; }","export BACKEND_IMAGE=\"${{ vars.BACKEND_IMAGE || '"'"'522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-backend'"'"' }}:${{ github.sha }}\"","export FRONTEND_IMAGE=\"${{ vars.FRONTEND_IMAGE || '"'"'522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-frontend'"'"' }}:${{ github.sha }}\"","export SMS_API_DOMAIN=\"${{ vars.SMS_API_DOMAIN || '"'"'api.sms.typerelations.com'"'"' }}\"","export SMS_FRONTEND_DOMAIN=\"${{ vars.SMS_FRONTEND_DOMAIN || '"'"'sms.typerelations.com'"'"' }}\""," /tmp/redeploy-application.sh 2>&1 | tee /tmp/redeploy.log","REDEPLOY_EXIT_CODE=${PIPESTATUS[0]}","echo \"\"","echo \"📋 Redeployment completed with exit code: $REDEPLOY_EXIT_CODE\"","if [ $REDEPLOY_EXIT_CODE -eq 0 ]; then","  echo \"✅ Redeployment successful\"","else","  echo \"❌ Redeployment failed\"","  echo \"📜 Last 20 lines of redeploy log:\"","  tail -20 /tmp/redeploy.log || echo \"Cannot read redeploy log\"","fi","exit $REDEPLOY_EXIT_CODE"]'"'"' \\\
          --comment "SMS Seller Connect Application Redeployment (Fixed JSON)" \\\
          --query '"'"'Command.CommandId'"'"' \\\
          --output text)' "$WORKFLOW_FILE"

echo "✅ SSM parameter parsing fix applied!"
echo ""
echo "📋 What was fixed:"
echo "  - Removed complex multi-line bash script from SSM parameters"
echo "  - Replaced with simple S3 download + execute approach"
echo "  - Fixed JSON parsing errors in AWS SSM send-command"
echo "  - Maintained all required environment variables and functionality"
echo ""
echo "📤 Next steps:"
echo "1. Review the changes in the workflow file"
echo "2. Commit and push the fix"
echo "3. Re-run the failed workflow"
echo ""
echo "🔍 To see what changed:"
echo "git diff $WORKFLOW_FILE" 