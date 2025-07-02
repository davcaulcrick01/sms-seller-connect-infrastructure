#!/bin/bash

# Enable GitHub Code Scanning for SMS Seller Connect Repository
# This script enables code scanning to allow SARIF uploads from Trivy security scans

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Enabling GitHub Code Scanning...${NC}"
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

REPO="davcaulcrick01/sms-seller-connect-infrastructure"

echo -e "${YELLOW}Checking current repository settings...${NC}"

# Check if code scanning is already enabled
echo -e "${YELLOW}Testing code scanning status...${NC}"
if gh api repos/$REPO/code-scanning/alerts --method GET >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Code scanning is already enabled!${NC}"
else
    echo -e "${YELLOW}Code scanning is not enabled. Attempting to enable...${NC}"
    
    # Enable vulnerability alerts (prerequisite for code scanning)
    echo -e "${YELLOW}Enabling vulnerability alerts...${NC}"
    gh api repos/$REPO/vulnerability-alerts --method PUT || echo -e "${YELLOW}Vulnerability alerts may already be enabled${NC}"
    
    # Enable Dependabot alerts (prerequisite for code scanning)
    echo -e "${YELLOW}Enabling Dependabot alerts...${NC}"
    gh api repos/$REPO/automated-security-fixes --method PUT || echo -e "${YELLOW}Dependabot may already be enabled${NC}"
    
    echo -e "${GREEN}✓ Security features enabled${NC}"
fi

echo ""
echo -e "${BLUE}📋 Manual Steps Required:${NC}"
echo -e "${YELLOW}Since code scanning cannot be fully automated via API, please follow these steps:${NC}"
echo ""
echo -e "1. Go to: https://github.com/$REPO/settings/security_analysis"
echo -e "2. Under 'Code scanning', click 'Set up' → 'Advanced'"
echo -e "3. This will create a .github/workflows/codeql.yml file"
echo -e "4. Commit the file to enable code scanning"
echo ""
echo -e "${BLUE}Alternative: Create CodeQL workflow automatically${NC}"

# Create CodeQL workflow
mkdir -p .github/workflows

cat > .github/workflows/codeql.yml << 'CODEQL_EOF'
name: "CodeQL"

on:
  push:
    branches: [ "main", "master" ]
  pull_request:
    branches: [ "main", "master" ]
  schedule:
    - cron: '0 0 * * 0'  # Weekly scan

jobs:
  analyze:
    name: Analyze
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write

    strategy:
      fail-fast: false
      matrix:
        language: [ 'javascript', 'python' ]

    steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Initialize CodeQL
      uses: github/codeql-action/init@v3
      with:
        languages: ${{ matrix.language }}

    - name: Autobuild
      uses: github/codeql-action/autobuild@v3

    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@v3
      with:
        category: "/language:${{matrix.language}}"
CODEQL_EOF

echo -e "${GREEN}✓ Created .github/workflows/codeql.yml${NC}"
echo ""
echo -e "${YELLOW}🔄 Next Steps:${NC}"
echo -e "1. Commit and push the new CodeQL workflow:"
echo -e "   git add .github/workflows/codeql.yml"
echo -e "   git commit -m 'Enable GitHub Code Scanning with CodeQL'"
echo -e "   git push"
echo ""
echo -e "2. Wait for the CodeQL workflow to run (this enables code scanning)"
echo ""
echo -e "3. After that, your Trivy SARIF uploads will work correctly"
echo ""
echo -e "${BLUE}📝 What this enables:${NC}"
echo -e "  • Security vulnerability scanning"
echo -e "  • SARIF file uploads from Trivy"
echo -e "  • Code quality analysis"
echo -e "  • Security alerts in repository"
echo ""
