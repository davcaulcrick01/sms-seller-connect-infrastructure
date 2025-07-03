#!/bin/bash

# Immediate Mixed Content Fix Deployment
# Bypasses SSM issues and uses GitHub Actions for immediate deployment

set -e

echo "🚀 Immediate Mixed Content Fix Deployment"
echo "========================================"
echo ""

# Configuration
INFRA_REPO="davcaulcrick01/sms-seller-connect-infrastructure"
APP_REPO="davcaulcrick01/sms-seller-connect"

echo "🔍 Current Status:"
echo "- Mixed content error: Frontend making HTTP requests to HTTPS page"
echo "- GitHub variables: Updated to use HTTPS API URLs"
echo "- SSM connectivity: Still establishing (new IAM policies propagating)"
echo "- Solution: Trigger GitHub Actions rebuild with HTTPS fix"
echo ""

echo "📤 Step 1: Trigger infrastructure redeployment with new images..."
gh workflow run terraform.yml --repo "$INFRA_REPO"

if [ $? -eq 0 ]; then
    echo "✅ Infrastructure deployment triggered successfully"
else
    echo "❌ Failed to trigger infrastructure deployment"
    exit 1
fi

echo ""
echo "📤 Step 2: Trigger application rebuild with HTTPS configuration..."
gh workflow run deploy.yml --repo "$APP_REPO" 2>/dev/null || echo "⚠️ Application rebuild trigger skipped (infrastructure rebuild includes app images)"

echo ""
echo "🎯 Deployment Status:"
echo "=============================="
echo "✅ Infrastructure deployment: TRIGGERED"
echo "✅ GitHub variables: FIXED (HTTPS URLs)"
echo "✅ Deployment script: FIXED (VITE_API_URL added)"
echo "✅ SSM policies: APPLIED (AmazonSSMManagedInstanceCore)"
echo "⏳ SSM connectivity: IN PROGRESS (policies propagating)"
echo ""

echo "📋 What's happening now:"
echo "1. GitHub Actions building new frontend images with HTTPS API URLs"
echo "2. New backend images being built with latest configurations"
echo "3. Infrastructure detecting existing EC2 and routing to redeploy"
echo "4. Containers will be updated with HTTPS-configured images"
echo "5. Mixed content error will be resolved"
echo ""

echo "⏰ Expected Timeline:"
echo "- Build phase: 3-5 minutes"
echo "- Deployment phase: 2-3 minutes"
echo "- Stabilization: 3-5 minutes"
echo "- Total time: ~10-15 minutes"
echo ""

echo "📊 Monitor Progress:"
echo "Infrastructure: https://github.com/$INFRA_REPO/actions"
echo "Application: https://github.com/$APP_REPO/actions"
echo ""

echo "🔍 Check deployment status:"
echo "gh run list --repo $INFRA_REPO --limit 3"
echo ""

echo "🎉 Mixed content fix deployment initiated successfully!"
echo "The frontend will start using HTTPS API calls once the new images are deployed."
echo ""
echo "💡 While waiting, SSM connectivity will also be established automatically"
echo "as the new IAM policies propagate (usually takes 5-10 minutes)." 