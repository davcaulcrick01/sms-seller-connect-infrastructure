#!/bin/bash

# Test GitHub Variables and Secrets Configuration
# This script helps verify that all required GitHub secrets and variables are properly set
# by testing the actual values that would be used in deployment

set -e

echo "🔐 Testing SMS Seller Connect GitHub Configuration"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track issues
issues_found=0

# Function to check if a value is set and not empty
check_value() {
    local name="$1"
    local value="$2"
    local is_secret="$3"
    local fallback="$4"
    
    if [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "None" ]; then
        if [ "$is_secret" = "true" ]; then
            echo -e "${GREEN}✅ $name${NC} - Set (${#value} chars)"
        else
            echo -e "${GREEN}✅ $name${NC} - $value"
        fi
    elif [ -n "$fallback" ]; then
        echo -e "${YELLOW}⚠️ $name${NC} - Using fallback: $fallback"
    else
        echo -e "${RED}❌ $name${NC} - Missing (required)"
        ((issues_found++))
    fi
}

echo "### Testing with Current Environment Variables"
echo "(These should match your GitHub secrets/variables)"
echo ""

echo "🔑 **Critical Secrets:**"
check_value "AWS_ACCESS_KEY_ID" "$AWS_ACCESS_KEY_ID" "true"
check_value "AWS_SECRET_ACCESS_KEY" "$AWS_SECRET_ACCESS_KEY" "true"
check_value "DB_HOST" "$DB_HOST" "false"
check_value "DB_USER" "$DB_USER" "false"
check_value "DB_PASSWORD" "$DB_PASSWORD" "true"

echo ""
echo "🔐 **Application Secrets:**"
check_value "FLASK_SECRET_KEY" "$FLASK_SECRET_KEY" "true"
check_value "JWT_SECRET_KEY" "$JWT_SECRET_KEY" "true"
check_value "TWILIO_ACCOUNT_SID" "$TWILIO_ACCOUNT_SID" "false"
check_value "TWILIO_AUTH_TOKEN" "$TWILIO_AUTH_TOKEN" "true"
check_value "TWILIO_PHONE_NUMBER" "$TWILIO_PHONE_NUMBER" "false"
check_value "OPENAI_API_KEY" "$OPENAI_API_KEY" "true"
check_value "SENDGRID_API_KEY" "$SENDGRID_API_KEY" "true"

echo ""
echo "🖥️ **Infrastructure Variables:**"
check_value "BACKEND_IMAGE" "$BACKEND_IMAGE" "false" "Should use commit SHA or latest ECR tag, not :latest"
check_value "FRONTEND_IMAGE" "$FRONTEND_IMAGE" "false" "Should use commit SHA or latest ECR tag, not :latest"
check_value "SMS_API_DOMAIN" "$SMS_API_DOMAIN" "false" "api.sms.typerelations.com"
check_value "SMS_FRONTEND_DOMAIN" "$SMS_FRONTEND_DOMAIN" "false" "sms.typerelations.com"

echo ""
echo "📧 **Email Configuration:**"
check_value "SENDGRID_FROM_EMAIL" "$SENDGRID_FROM_EMAIL" "false" "noreply@typerelations.com"
check_value "HOT_LEAD_EMAIL_RECIPIENTS" "$HOT_LEAD_EMAIL_RECIPIENTS" "false" "dcaulcrick01@gmail.com"
check_value "HOT_LEAD_SMS_RECIPIENTS" "$HOT_LEAD_SMS_RECIPIENTS" "false"

echo ""
echo "🗄️ **Database Configuration:**"
check_value "DB_PORT" "$DB_PORT" "false" "5437"
check_value "DB_NAME" "$DB_NAME" "false" "sms_blast"

echo ""
echo "🔧 **Optional Configuration:**"
check_value "SSH_PUBLIC_KEY" "$SSH_PUBLIC_KEY" "true"
check_value "NGROK_AUTH_TOKEN" "$NGROK_AUTH_TOKEN" "true"
check_value "OPENAI_MODEL" "$OPENAI_MODEL" "false" "gpt-4o"
check_value "OPENAI_TEMPERATURE" "$OPENAI_TEMPERATURE" "false" "0.3"

echo ""
echo "=================================================="

if [ $issues_found -eq 0 ]; then
    echo -e "${GREEN}🎉 All critical configuration appears to be set!${NC}"
    echo ""
    echo "✅ You can proceed with deployment"
    echo "✅ Consider running 'verify-secrets' action in GitHub for complete validation"
else
    echo -e "${RED}❌ Found $issues_found configuration issues${NC}"
    echo ""
    echo "🔧 To fix these issues:"
    echo "1. Go to your GitHub repository"
    echo "2. Navigate to Settings > Secrets and variables > Actions"
    echo "3. Add the missing secrets/variables"
    echo "4. Run the 'verify-secrets' action to confirm"
    exit 1
fi

echo ""
echo "📋 **Next Steps:**"
echo "1. Run 'verify-secrets' action in GitHub Actions to validate"
echo "2. Use 'redeploy' action to update your application"
echo "3. Monitor deployment logs for any issues"

echo ""
echo "🔗 **Useful Commands:**"
echo "• Verify in GitHub: Go to Actions > Run workflow > verify-secrets"
echo "• Redeploy app: Go to Actions > Run workflow > redeploy"
echo "• Check EC2 status: aws ec2 describe-instances --filters \"Name=tag:Name,Values=sms-seller-connect-prod-ec2\""

echo ""
echo "📚 **Documentation:**"
echo "• Pipeline usage: See PIPELINE-USAGE.md"
echo "• Troubleshooting: Check GitHub Actions logs" 