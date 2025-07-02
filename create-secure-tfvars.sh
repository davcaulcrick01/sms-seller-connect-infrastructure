#!/bin/bash

echo "🔐 SMS Seller Connect - Secure Terraform Configuration Setup"
echo "==========================================================="
echo ""
echo "⚠️  WARNING: Never commit terraform.tfvars with real secrets to version control!"
echo ""

# Check if terraform.tfvars already exists
if [ -f "modules/ec2/terraform.tfvars" ]; then
    echo "❌ terraform.tfvars already exists!"
    echo "   If you want to recreate it, delete it first:"
    echo "   rm modules/ec2/terraform.tfvars"
    echo ""
    exit 1
fi

# Create terraform.tfvars from template
echo "📋 Creating terraform.tfvars from template..."
cp modules/ec2/terraform.tfvars.template modules/ec2/terraform.tfvars

echo ""
echo "✅ terraform.tfvars created from template"
echo ""
echo "🔧 NEXT STEPS:"
echo "=============="
echo "1. Edit modules/ec2/terraform.tfvars with your actual values:"
echo "   - Replace ALL placeholder values (YOUR_*)"
echo "   - Generate secure random keys for secrets"
echo "   - Add your actual API keys and credentials"
echo ""
echo "2. Secure the file:"
echo "   chmod 600 modules/ec2/terraform.tfvars"
echo ""
echo "3. Add to .gitignore if not already there:"
echo "   echo 'modules/ec2/terraform.tfvars' >> .gitignore"
echo ""
echo "🔑 To generate secure random secrets, use:"
echo "   openssl rand -hex 32  # For 256-bit keys"
echo "   openssl rand -base64 32  # For base64 encoded keys"
echo ""
echo "⚠️  IMPORTANT: Keep your terraform.tfvars file secure and never commit it!" 