#!/bin/bash

# Trigger Redeployment via GitHub Actions - Alternative to SSM
# This approach uses the existing CI/CD pipeline to redeploy

set -e

REPO_OWNER="davcaulcrick01"
REPO_NAME="sms-seller-connect-infrastructure"

echo "🚀 Triggering redeployment via GitHub Actions..."
echo "Repository: $REPO_OWNER/$REPO_NAME"
echo ""

# Check if GitHub CLI is installed and authenticated
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed. Please install it first."
    echo "Visit: https://cli.github.com/"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "❌ Please authenticate with GitHub CLI first:"
    echo "Run: gh auth login"
    exit 1
fi

echo "🔍 Checking if EC2 instance is running..."
INSTANCE_ID=$(aws ec2 describe-instances \
    --region "us-east-1" \
    --filters \
        "Name=tag:Name,Values=sms-seller-connect-prod-ec2" \
        "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
    echo "❌ No running SMS Seller Connect instance found!"
    echo "💡 You need to deploy infrastructure first."
    echo ""
    echo "🚀 Would you like to trigger a full infrastructure deployment? (y/n)"
    read -r DEPLOY_INFRA
    if [ "$DEPLOY_INFRA" = "y" ] || [ "$DEPLOY_INFRA" = "Y" ]; then
        WORKFLOW_NAME="terraform.yml"
        WORKFLOW_DESCRIPTION="Full infrastructure deployment"
    else
        echo "ℹ️ Deployment cancelled."
        exit 0
    fi
else
    echo "✅ Found running instance: $INSTANCE_ID"
    echo ""
    echo "🔄 The infrastructure exists, so we'll trigger a redeploy workflow."
    echo "This will update the running containers with the latest images."
    WORKFLOW_NAME="terraform.yml"
    WORKFLOW_DESCRIPTION="Redeploy existing infrastructure"
fi

echo ""
echo "📤 Triggering GitHub Actions workflow: $WORKFLOW_NAME"
echo "Description: $WORKFLOW_DESCRIPTION"

# Trigger the workflow
gh workflow run "$WORKFLOW_NAME" \
    --repo "$REPO_OWNER/$REPO_NAME" \
    --ref main

echo ""
echo "✅ Workflow triggered successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Monitor the workflow progress:"
echo "   https://github.com/$REPO_OWNER/$REPO_NAME/actions"
echo ""
echo "2. The workflow will:"
echo "   - Build new images with the HTTPS fix"
echo "   - Deploy/redeploy the infrastructure"
echo "   - Run health checks to verify deployment"
echo ""
echo "3. Expected completion time: 10-15 minutes"
echo ""
echo "📊 Check workflow status:"
echo "gh run list --repo $REPO_OWNER/$REPO_NAME --limit 5" 