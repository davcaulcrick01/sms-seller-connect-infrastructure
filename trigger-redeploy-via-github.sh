#!/bin/bash

echo "🚀 TRIGGER SMS SELLER CONNECT REDEPLOYMENT"
echo "=========================================="
echo ""

# Configuration
REPO_OWNER="davcaulcrick01"
REPO_NAME="sms-seller-connect-infrastructure"
WORKFLOW_NAME="terraform.yml"
BRANCH="main"

echo "📋 Repository: $REPO_OWNER/$REPO_NAME"
echo "🌿 Branch: $BRANCH"
echo "⚙️  Workflow: $WORKFLOW_NAME"
echo ""

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed"
    echo "📥 Install with: brew install gh"
    echo ""
    echo "🔗 Alternative: Manually trigger workflow at:"
    echo "   https://github.com/$REPO_OWNER/$REPO_NAME/actions/workflows/$WORKFLOW_NAME"
    echo ""
    echo "👆 Click 'Run workflow' button on that page"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "🔐 Authenticating with GitHub..."
    gh auth login
fi

echo "🚀 Triggering workflow dispatch..."

# Trigger the workflow
if gh workflow run "$WORKFLOW_NAME" \
    --repo "$REPO_OWNER/$REPO_NAME" \
    --ref "$BRANCH"; then
    
    echo "✅ Workflow triggered successfully!"
    echo ""
    echo "🔍 Monitor the workflow at:"
    echo "   https://github.com/$REPO_OWNER/$REPO_NAME/actions"
    echo ""
    echo "📊 The improved pipeline will now:"
    echo "  ✅ Restart SSM agent to pick up new IAM permissions"
    echo "  ✅ Use fallback deployment if SSM fails"
    echo "  ✅ Set VITE_API_URL=https://api.sms.typerelations.com"
    echo "  ✅ Deploy with HTTPS configuration"
    echo ""
    echo "⏱️  Expected completion: 10-15 minutes"
    echo "🎯 This will resolve the mixed content security error!"
    
else
    echo "❌ Failed to trigger workflow"
    echo ""
    echo "🔗 Manual trigger: https://github.com/$REPO_OWNER/$REPO_NAME/actions/workflows/$WORKFLOW_NAME"
fi 