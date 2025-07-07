#!/bin/bash

echo "🔍 SMS Seller Connect - Infrastructure Validation"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Function to print status
print_status() {
    local status=$1
    local message=$2
    case $status in
        "PASS")
            echo -e "${GREEN}✅ PASS${NC}: $message"
            ((PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}❌ FAIL${NC}: $message"
            ((FAILED++))
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  WARN${NC}: $message"
            ((WARNINGS++))
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  INFO${NC}: $message"
            ;;
    esac
}

# Check if we're in the right directory
check_directory() {
    echo "🏗️  Checking Infrastructure Directory Structure..."
    echo "================================================"
    
    if [ ! -d "modules/ec2" ]; then
        print_status "FAIL" "modules/ec2 directory not found. Are you in the Infrastructure/sms-seller-connect directory?"
        exit 1
    fi
    
    print_status "PASS" "Infrastructure directory structure found"
    echo ""
}

# Check terraform configuration files
check_terraform_files() {
    echo "📋 Checking Terraform Configuration Files..."
    echo "==========================================="
    
    local required_files=(
        "modules/ec2/main.tf"
        "modules/ec2/variables.tf"
        "modules/ec2/outputs.tf"
        "modules/ec2/data.tf"
        "modules/ec2/ec2.tf"
        "modules/ec2/alb.tf"
        "modules/ec2/route53.tf"
        "modules/ec2/s3.tf"
        "modules/ec2/iam.tf"
        "modules/ec2/sg.tf"
        "modules/ec2/acm.tf"
        "modules/ec2/cloudwatch.tf"
        "modules/ec2/locals.tf"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            print_status "PASS" "Found $file"
        else
            print_status "FAIL" "Missing $file"
        fi
    done
    echo ""
}

# Check configuration files
check_config_files() {
    echo "⚙️  Checking Configuration Files..."
    echo "=================================="
    
    local config_files=(
        "modules/ec2/config/docker-compose.yml"
        "modules/ec2/config/nginx.conf"
        "modules/ec2/config/.env.template"
    )
    
    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            print_status "PASS" "Found $file"
        else
            print_status "FAIL" "Missing $file"
        fi
    done
    
    # Check nginx configuration for variables
    if [ -f "modules/ec2/config/nginx.conf" ]; then
        if grep -q '${SMS_API_DOMAIN}' modules/ec2/config/nginx.conf; then
            print_status "PASS" "nginx.conf contains variable placeholders (good for template)"
        else
            print_status "WARN" "nginx.conf may not have variable placeholders"
        fi
    fi
    echo ""
}

# Check scripts
check_scripts() {
    echo "🔧 Checking Scripts..."
    echo "===================="
    
    local scripts=(
        "modules/ec2/scripts/user_data.sh"
        "modules/ec2/scripts/health-check.sh"
        "modules/ec2/scripts/health-check-server.py"
        "modules/ec2/scripts/bootstrap.sh"
        "modules/ec2/scripts/maintenance.sh"
        "modules/ec2/scripts/fix-nginx-domain-routing.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            print_status "PASS" "Found $script"
            if [ -x "$script" ]; then
                print_status "PASS" "$script is executable"
            else
                print_status "WARN" "$script is not executable (chmod +x needed)"
            fi
        else
            print_status "FAIL" "Missing $script"
        fi
    done
    
    # Check if user_data.sh has nginx variable substitution
    if [ -f "modules/ec2/scripts/user_data.sh" ]; then
        if grep -q "envsubst.*nginx" modules/ec2/scripts/user_data.sh; then
            print_status "PASS" "user_data.sh includes nginx variable substitution"
        else
            print_status "FAIL" "user_data.sh missing nginx variable substitution"
        fi
    fi
    echo ""
}

# Check security
check_security() {
    echo "🔒 Checking Security Configuration..."
    echo "===================================="
    
    # Check if sensitive terraform.tfvars exists
    if [ -f "modules/ec2/terraform.tfvars" ]; then
        print_status "WARN" "terraform.tfvars exists - ensure it's not committed to version control"
        
        # Check file permissions
        local perms=$(stat -f "%OLp" modules/ec2/terraform.tfvars 2>/dev/null || stat -c "%a" modules/ec2/terraform.tfvars 2>/dev/null)
        if [ "$perms" = "600" ]; then
            print_status "PASS" "terraform.tfvars has secure permissions (600)"
        else
            print_status "WARN" "terraform.tfvars permissions: $perms (should be 600)"
        fi
        
        # Check for placeholder values
        if grep -q "YOUR_" modules/ec2/terraform.tfvars; then
            print_status "FAIL" "terraform.tfvars contains placeholder values - needs real configuration"
        else
            print_status "PASS" "terraform.tfvars appears to have real values"
        fi
    else
        print_status "INFO" "terraform.tfvars not found - use create-secure-tfvars.sh to create it"
    fi
    
    # Check template exists
    if [ -f "modules/ec2/terraform.tfvars.template" ]; then
        print_status "PASS" "terraform.tfvars.template exists"
    else
        print_status "FAIL" "terraform.tfvars.template missing"
    fi
    
    # Check .gitignore
    if [ -f ".gitignore" ]; then
        if grep -q "terraform.tfvars" .gitignore; then
            print_status "PASS" ".gitignore excludes terraform.tfvars"
        else
            print_status "FAIL" ".gitignore does not exclude terraform.tfvars"
        fi
    else
        print_status "FAIL" ".gitignore missing"
    fi
    echo ""
}

# Check terraform syntax
check_terraform_syntax() {
    echo "📋 Checking Terraform Syntax..."
    echo "==============================="
    
    cd modules/ec2
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_status "WARN" "Terraform not installed - skipping syntax check"
        cd ../..
        return
    fi
    
    # Initialize terraform (quietly)
    if terraform init -backend=false &> /dev/null; then
        print_status "PASS" "Terraform initialization successful"
    else
        print_status "FAIL" "Terraform initialization failed"
        cd ../..
        return
    fi
    
    # Validate terraform configuration
    if terraform validate &> /dev/null; then
        print_status "PASS" "Terraform configuration is valid"
    else
        print_status "FAIL" "Terraform configuration has syntax errors"
        echo "Run 'terraform validate' in modules/ec2 for details"
    fi
    
    cd ../..
    echo ""
}

# Check documentation
check_documentation() {
    echo "📚 Checking Documentation..."
    echo "==========================="
    
    local docs=(
        "README.md"
        "modules/ec2/README.md"
        "DEPLOYMENT-READINESS-CHECKLIST.md"
        "TERRAFORM-USAGE.md"
        "VARIABLE-FLOW-DOCUMENTATION.md"
    )
    
    for doc in "${docs[@]}"; do
        if [ -f "$doc" ]; then
            print_status "PASS" "Found $doc"
        else
            print_status "WARN" "Missing $doc"
        fi
    done
    echo ""
}

# Main execution
main() {
    check_directory
    check_terraform_files
    check_config_files
    check_scripts
    check_security
    check_terraform_syntax
    check_documentation
    
    echo "📊 Validation Summary"
    echo "===================="
    echo -e "${GREEN}Passed: $PASSED${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo -e "${RED}Failed: $FAILED${NC}"
    echo ""
    
    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 Infrastructure validation completed successfully!${NC}"
        if [ $WARNINGS -gt 0 ]; then
            echo -e "${YELLOW}Note: $WARNINGS warnings found - review above${NC}"
        fi
        echo ""
        echo "✅ Ready for deployment!"
        echo ""
        echo "🚀 Next steps:"
        echo "1. Configure terraform.tfvars with your values"
        echo "2. Run: cd modules/ec2 && terraform plan"
        echo "3. Run: terraform apply"
        exit 0
    else
        echo -e "${RED}❌ Infrastructure validation failed with $FAILED errors${NC}"
        echo ""
        echo "🔧 Fix the errors above before deployment"
        exit 1
    fi
}

# Run main function
main 