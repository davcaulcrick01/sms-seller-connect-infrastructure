#!/bin/bash

echo "🔧 Setting up Terraform Backend Infrastructure"
echo "============================================="

# Navigate to backend setup directory
cd backend-setup || { echo "❌ Backend setup directory not found"; exit 1; }

echo "📋 This script will create:"
echo "  - S3 bucket: greyzone-terraform-state" 
echo "  - DynamoDB table: terraform-locks"
echo "  - Proper bucket policies and encryption"
echo ""

# Initialize Terraform (no backend since we're creating the backend)
echo "🔧 Initializing Terraform..."
terraform init

# Plan the backend infrastructure
echo "📋 Planning backend infrastructure..."
terraform plan

# Apply the backend infrastructure
echo "🚀 Creating backend infrastructure..."
terraform apply -auto-approve

# Show outputs
echo "📊 Backend infrastructure outputs:"
terraform output

echo ""
echo "✅ Backend setup completed!"
echo "🎯 You can now run terraform plan/apply in the main modules/ec2 directory"

# Navigate back
cd ..

echo ""
echo "📋 Next steps:"
echo "1. cd modules/ec2"
echo "2. terraform init"
echo "3. terraform plan -var-file=terraform.tfvars"
echo "4. terraform apply -var-file=terraform.tfvars" 