# SMS Seller Connect - Terraform Usage Guide

## 🚀 Quick Fix Applied

**Problem Solved**: GitHub Actions was failing with "terraform.tfvars does not exist" error.

**Root Cause**: Terraform automatically looks for `terraform.tfvars` file, but this file exists locally (and is in .gitignore) but not in GitHub Actions runner.

**Solution**: Removed all `-var-file=terraform.tfvars` references from GitHub Actions workflow. Now it uses **only** environment variables from GitHub secrets/variables.

## 📋 How It Works Now

### GitHub Actions (Production)
- ✅ Uses **only** `TF_VAR_*` environment variables from GitHub secrets/variables
- ✅ No tfvars file needed or used
- ✅ All your existing secrets and variables work unchanged
- ✅ Pipeline will now run successfully

### Local Development  
- ✅ Uses your local `terraform.tfvars` file (already exists)
- ✅ Run with: `terraform plan -var-file=terraform.tfvars`
- ✅ File is in .gitignore (secure)

## 🔧 Commands

### GitHub Actions (Automatic)
```bash
# These commands run automatically in GitHub Actions:
terraform plan -input=false -detailed-exitcode -no-color -out=tfplan
terraform apply -auto-approve
terraform destroy -auto-approve
```

### Local Development
```bash
# For local development:
cd modules/ec2
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## ✅ Status

- **GitHub Actions**: ✅ Fixed - will use environment variables only
- **Local Development**: ✅ Working - uses terraform.tfvars file  
- **Security**: ✅ Maintained - secrets stay in GitHub, tfvars in .gitignore

Your pipeline should now work without the "terraform.tfvars does not exist" error! 