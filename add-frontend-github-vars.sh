#!/bin/bash

# Add Frontend Environment Variables to GitHub Actions
# This script adds the VITE_ variables needed for the frontend build

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Adding Frontend Environment Variables to GitHub Actions...${NC}"
echo ""

# Check if GitHub CLI is installed and authenticated
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed!${NC}"
    echo -e "${YELLOW}Please install it from: https://cli.github.com/${NC}"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub CLI!${NC}"
    echo -e "${YELLOW}Please run: gh auth login${NC}"
    exit 1
fi

# Function to add GitHub variable
add_variable() {
    local name=$1
    local value=$2
    
    echo -e "${YELLOW}Adding variable: $name = $value${NC}"
    gh variable set "$name" --body "$value"
    echo -e "${GREEN}✓ Variable $name added${NC}"
}

echo -e "${BLUE}📋 Adding Frontend Environment Variables...${NC}"

# Frontend API Configuration - Updated to use ALB domain
add_variable "VITE_API_URL" "https://sms-seller-connect-prod-alb-1244462026.us-east-1.elb.amazonaws.com"
add_variable "VITE_BACKEND_PORT" "8900"

# Frontend App Configuration
add_variable "VITE_APP_NAME" "SMS Seller Connect"
add_variable "VITE_APP_VERSION" "1.0.0"

# Frontend Feature Flags
add_variable "VITE_FEATURE_AI_SUGGESTIONS" "true"
add_variable "VITE_FEATURE_BULK_MESSAGING" "true"
add_variable "VITE_FEATURE_ANALYTICS_DASHBOARD" "true"
add_variable "VITE_FEATURE_ADVANCED_FLOWS" "true"
add_variable "VITE_FEATURE_LEAD_SCORING" "true"

# Frontend Development Settings
add_variable "VITE_ENABLE_ANALYTICS" "false"
add_variable "VITE_LOG_LEVEL" "info"

# Frontend AI Configuration
add_variable "VITE_OPENAI_MODEL" "gpt-4"
add_variable "VITE_ENABLE_AI_SUGGESTIONS" "true"

echo ""
echo -e "${GREEN}✅ All frontend environment variables have been added to GitHub Actions!${NC}"
echo ""
echo -e "${BLUE}📋 Summary of added variables:${NC}"
echo -e "  • VITE_API_URL (points to ALB)"
echo -e "  • VITE_BACKEND_PORT"
echo -e "  • VITE_APP_NAME"
echo -e "  • VITE_APP_VERSION"
echo -e "  • VITE_FEATURE_* (5 feature flags)"
echo -e "  • VITE_ENABLE_ANALYTICS"
echo -e "  • VITE_LOG_LEVEL"
echo -e "  • VITE_OPENAI_MODEL"
echo -e "  • VITE_ENABLE_AI_SUGGESTIONS"
echo ""
echo -e "${YELLOW}🔄 Next steps:${NC}"
echo -e "  1. Trigger a new deployment in GitHub Actions"
echo -e "  2. The frontend will now use the correct API URL"
echo -e "  3. Login should work with: admin@smssellerconnect.com / admin"
echo "" 