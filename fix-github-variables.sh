#!/bin/bash

# Fix GitHub Repository Variables - SMS Seller Connect
# This script updates GitHub repository variables to use HTTPS URLs

set -e

REPO_OWNER="davcaulcrick01"
REPO_NAME="sms-seller-connect"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Fixing GitHub Repository Variables for SMS Seller Connect${NC}"
echo "=========================================="

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed. Please install it first.${NC}"
    echo "Visit: https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Please authenticate with GitHub CLI first:${NC}"
    echo "Run: gh auth login"
    exit 1
fi

echo -e "${YELLOW}📝 Current GitHub repository variables:${NC}"
gh variable list -R "${REPO_OWNER}/${REPO_NAME}" || echo "No variables found or access denied"

echo ""
echo -e "${BLUE}🔄 Updating repository variables with HTTPS URLs...${NC}"

# Frontend API Configuration (CRITICAL - this fixes the mixed content error)
echo -e "${GREEN}✅ Setting VITE_API_URL to HTTPS...${NC}"
gh variable set VITE_API_URL -b "https://api.sms.typerelations.com" -R "${REPO_OWNER}/${REPO_NAME}"

# Frontend App Configuration
echo -e "${GREEN}✅ Setting frontend app configuration...${NC}"
gh variable set VITE_APP_NAME -b "SMS Seller Connect" -R "${REPO_OWNER}/${REPO_NAME}"
gh variable set VITE_APP_VERSION -b "1.0.0" -R "${REPO_OWNER}/${REPO_NAME}"

# Frontend Feature Flags
echo -e "${GREEN}✅ Setting frontend feature flags...${NC}"
gh variable set VITE_FEATURE_AI_SUGGESTIONS -b "true" -R "${REPO_OWNER}/${REPO_NAME}"
gh variable set VITE_FEATURE_BULK_MESSAGING -b "true" -R "${REPO_OWNER}/${REPO_NAME}"
gh variable set VITE_FEATURE_ANALYTICS_DASHBOARD -b "true" -R "${REPO_OWNER}/${REPO_NAME}"
gh variable set VITE_FEATURE_ADVANCED_FLOWS -b "true" -R "${REPO_OWNER}/${REPO_NAME}"
gh variable set VITE_FEATURE_LEAD_SCORING -b "true" -R "${REPO_OWNER}/${REPO_NAME}"

# Frontend Development Settings
echo -e "${GREEN}✅ Setting frontend development settings...${NC}"
gh variable set VITE_ENABLE_ANALYTICS -b "false" -R "${REPO_OWNER}/${REPO_NAME}"
gh variable set VITE_LOG_LEVEL -b "info" -R "${REPO_OWNER}/${REPO_NAME}"

# Frontend AI Configuration
echo -e "${GREEN}✅ Setting frontend AI configuration...${NC}"
gh variable set VITE_OPENAI_MODEL -b "gpt-4" -R "${REPO_OWNER}/${REPO_NAME}"
gh variable set VITE_ENABLE_AI_SUGGESTIONS -b "true" -R "${REPO_OWNER}/${REPO_NAME}"

# ECR Repository Names
echo -e "${GREEN}✅ Setting ECR repository names...${NC}"
gh variable set ECR_BACKEND_REPOSITORY -b "sms-wholesaling-backend" -R "${REPO_OWNER}/${REPO_NAME}"
gh variable set ECR_FRONTEND_REPOSITORY -b "sms-wholesaling-frontend" -R "${REPO_OWNER}/${REPO_NAME}"

echo ""
echo -e "${BLUE}📋 Updated GitHub repository variables:${NC}"
gh variable list -R "${REPO_OWNER}/${REPO_NAME}"

echo ""
echo -e "${GREEN}🎉 GitHub repository variables have been updated successfully!${NC}"
echo -e "${YELLOW}⚠️  Important Next Steps:${NC}"
echo "1. Rebuild and redeploy the frontend to apply the HTTPS URL change"
echo "2. The mixed content error should be resolved after redeployment"
echo ""
echo -e "${BLUE}💡 To rebuild and redeploy:${NC}"
echo "1. Push a commit to trigger the CI/CD pipeline"
echo "2. Or manually run the 'Deploy Infrastructure' workflow"
echo ""
echo -e "${RED}🔒 Critical Security Note:${NC}"
echo "The VITE_API_URL is now set to HTTPS, which will fix the mixed content security error." 