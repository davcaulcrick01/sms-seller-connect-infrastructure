# SMS Seller Connect - Terraform Usage Guide

## 🚀 Quick Fix Applied

**Problem Solved**: GitHub Actions was failing with "terraform.tfvars does not exist" error.

**Root Cause**: Terraform automatically looks for `terraform.tfvars` file, but this file exists locally (and is in .gitignore) but not in GitHub Actions runner.

**Solution**: Removed all `-var-file=terraform.tfvars` references from GitHub Actions workflow. Now it uses **only** environment variables from GitHub secrets/variables.

## 🛡️ Protection Against Destruction

**NEW**: Added lifecycle protection rules to prevent accidental destruction of existing infrastructure:

- ✅ **EC2 instances**: `prevent_destroy = true` - won't be destroyed accidentally
- ✅ **S3 buckets**: `prevent_destroy = true` - data is protected  
- ✅ **Route53 zones**: `prevent_destroy = true` - DNS zones are safe
- ✅ **Ignore changes**: User data, AMI changes won't trigger recreation

## 📋 How It Works Now

### GitHub Actions (Production)
- ✅ Uses **only** `TF_VAR_*` environment variables from GitHub secrets/variables
- ✅ No tfvars file needed or used
- ✅ All your existing secrets and variables work unchanged
- ✅ Pipeline will now run successfully
- ✅ **Protected**: Won't destroy existing resources

### Local Development  
- ✅ Uses your local `terraform.tfvars` file (already exists)
- ✅ Run with: `terraform plan -var-file=terraform.tfvars`
- ✅ File is in .gitignore (secure)

## 🔧 Commands

### Check for Existing Resources First
```bash
# Run this before deploying to see what already exists:
./check-existing-resources.sh
```

### GitHub Actions (Automatic)
```bash
# These commands run automatically in GitHub Actions:
terraform plan -input=false -detailed-exitcode -no-color -out=tfplan
terraform apply -auto-approve
terraform destroy -auto-approve  # Protected by lifecycle rules
```

### Local Development
```bash
# For local development:
cd modules/ec2
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### Import Existing Resources (if needed)
```bash
# If you have existing resources, import them:
cd modules/ec2
# Edit import.tf with actual resource IDs
terraform plan   # Shows what will be imported
terraform apply  # Imports the resources
```

## 🔄 Handling Existing Resources

If you have existing AWS resources, you have 4 options:

### 1. 🔄 Import Existing Resources (Recommended)
```bash
# Check what exists first
./check-existing-resources.sh

# Edit modules/ec2/import.tf with actual resource IDs
# Then run:
cd modules/ec2
terraform plan && terraform apply
```

### 2. 🏷️ Rename Your Resources
Update your `terraform.tfvars` to use different names:
```hcl
bucket_name = "sms-seller-connect-bucket-v2"
instance_name = "sms-seller-connect-v2"
```

### 3. 🎯 Use Data Sources
Reference existing resources instead of creating new ones.

### 4. 🧹 Manual Cleanup
Only if you're sure the existing resources aren't needed.

## ✅ Status

- **GitHub Actions**: ✅ Fixed - will use environment variables only
- **Local Development**: ✅ Working - uses terraform.tfvars file  
- **Security**: ✅ Maintained - secrets stay in GitHub, tfvars in .gitignore
- **Protection**: ✅ Added - lifecycle rules prevent accidental destruction
- **Existing Resources**: ✅ Handled - multiple options available

## 🛡️ Safety Features

- **Lifecycle Protection**: Critical resources won't be destroyed accidentally
- **Import Support**: Existing resources can be imported safely
- **State Management**: Terraform state is preserved in S3
- **Version Control**: S3 bucket versioning enabled for config files

Your pipeline should now work without the "terraform.tfvars does not exist" error, and your existing infrastructure is protected! 🎉 