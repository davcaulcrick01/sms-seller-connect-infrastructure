# 🚀 GreyZone Rentals - CI/CD Pipeline Guide

## 📋 **Pipeline Overview**

This GitHub Actions workflow provides automated CI/CD for the GreyZone Rentals EC2 infrastructure with enhanced monitoring capabilities.

## 🎯 **Workflow Triggers**

### **Automatic Triggers**
- **Push to `main`**: Validates, plans, and applies changes
- **Push to `development`**: Validates and plans only
- **Pull Requests**: Validates, plans, and comments results

### **Manual Triggers**
- **Workflow Dispatch**: Manual control with action selection
  - `plan`: Validate and create plan
  - `apply`: Deploy infrastructure 
  - `destroy`: Remove infrastructure

## 🔧 **Pipeline Jobs**

### **1. Validate & Security Check** 🔍
- **Purpose**: Code quality and security validation
- **Actions**:
  - Terraform formatting check
  - Configuration validation
  - Security scan with `tfsec`
  - Artifact upload for security results

### **2. Plan** 📋
- **Purpose**: Create and review infrastructure changes
- **Actions**:
  - Backend health verification
  - Terraform plan generation
  - Plan summary and change analysis
  - PR comments with plan details
  - Plan artifact upload

### **3. Apply** 🚀
- **Purpose**: Deploy infrastructure changes
- **Triggers**:
  - Manual dispatch with `apply` action
  - Auto-apply on `main` branch (with approval)
- **Actions**:
  - Infrastructure deployment
  - Health checks and verification
  - CloudWatch dashboard creation
  - Deployment status reporting

### **4. Destroy** 💥
- **Purpose**: Remove all infrastructure
- **Trigger**: Manual dispatch with `destroy` action
- **Requires**: Explicit approval environment

## 🛡️ **Security Features**

### **Required Secrets**
```bash
AWS_ACCESS_KEY_ID      # AWS access key
AWS_SECRET_ACCESS_KEY  # AWS secret key
```

### **Security Scans**
- **tfsec**: Terraform security analysis
- **Format validation**: Code consistency
- **Backend verification**: State integrity

### **Approval Gates**
- **Production Environment**: Manual approval required
- **Destroy Environment**: Additional approval for destruction

## 📊 **Enhanced Monitoring Integration**

### **CloudWatch Dashboard**
- **Auto-created**: `GreyZone-Rentals-EC2`
- **Metrics**: CPU, Memory, Disk utilization
- **Namespace**: `CarRental/EC2`

### **Sentry Integration**
- **Organization**: `greyzone-intelligence`
- **Project**: `car-rental-web-app`
- **Auto-linked**: In deployment comments

### **Health Checks**
- **Application**: `/api/test-db` endpoint
- **Infrastructure**: EC2 instance status
- **Database**: Connection verification

## 🎮 **How to Use**

### **Development Workflow**
1. **Create Feature Branch**
   ```bash
   git checkout -b feature/your-feature
   ```

2. **Make Changes**
   - Edit Terraform files in `modules/ec2/`
   - Run local validation:
     ```bash
     terraform fmt -recursive
     terraform validate
     ```

3. **Create Pull Request**
   - Pipeline automatically validates
   - Plan results commented on PR
   - Review changes before merge

4. **Merge to Main**
   - Auto-deployment with approval gate
   - Monitor progress in Actions tab

### **Manual Deployment**
1. **Go to Actions Tab**
2. **Select Workflow**: "GreyZone Rentals - EC2 Infrastructure CI/CD"
3. **Click "Run workflow"**
4. **Choose Action**:
   - `plan`: Review changes
   - `apply`: Deploy changes
   - `destroy`: Remove infrastructure
5. **Monitor Progress**

### **Emergency Procedures**

#### **Rollback Deployment**
```bash
# Option 1: Revert commit and redeploy
git revert <commit-hash>
git push origin main

# Option 2: Manual intervention
# - Use AWS Console to modify resources
# - Update Terraform state manually
# - Re-run pipeline to sync
```

#### **State Lock Issues**
```bash
# Check for locks
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (use carefully)
terraform force-unlock <lock-id>
```

## 📈 **Monitoring & Alerts**

### **Pipeline Notifications**
- **Success**: Green checkmark with deployment details
- **Failure**: Red X with error information
- **PR Comments**: Detailed plan analysis

### **Infrastructure Monitoring**
- **CloudWatch**: Real-time metrics and logs
- **Sentry**: Error tracking and performance
- **Health Checks**: Application availability

### **Log Locations**
- **Pipeline Logs**: GitHub Actions interface
- **Application Logs**: CloudWatch `/aws/ec2/car-rental-app`
- **Error Tracking**: Sentry dashboard

## 🔧 **Configuration**

### **Environment Variables**
```yaml
AWS_REGION: us-east-1
STATE_BUCKET: car-rental-app-terraform-state
STATE_KEY: ec2/terraform.tfstate
LOCK_TABLE: terraform-state-lock
ECR_REPOSITORY: 522814698925.dkr.ecr.us-east-1.amazonaws.com/car-rental-app
DOMAIN_NAME: greyzonerentals.com
```

### **Terraform Backend**
```hcl
terraform {
  backend "s3" {
    bucket         = "car-rental-app-terraform-state"
    key            = "ec2/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

## 🚨 **Troubleshooting**

### **Common Issues**

#### **"Backend Not Found"**
- **Cause**: S3 bucket or DynamoDB table missing
- **Solution**: Create backend resources first
- **Check**: AWS Console for bucket/table existence

#### **"Plan Shows Unexpected Changes"**
- **Cause**: State drift or manual changes
- **Solution**: Review changes carefully
- **Action**: Use `terraform refresh` to sync state

#### **"Apply Failed"**
- **Cause**: Resource conflicts or permissions
- **Solution**: Check error logs in Actions
- **Debug**: Review CloudWatch logs for details

#### **"Security Scan Failed"**
- **Cause**: Security issues in Terraform code
- **Solution**: Review tfsec results
- **Action**: Fix security issues or add exceptions

### **Debug Commands**
```bash
# Local debugging
terraform plan -var-file=terraform.tfvars
terraform validate
terraform fmt -check -recursive

# State inspection
terraform state list
terraform state show <resource>

# Backend verification
aws s3 ls s3://car-rental-app-terraform-state
aws dynamodb describe-table --table-name terraform-state-lock
```

## 📚 **Best Practices**

### **Code Quality**
- ✅ Always format code: `terraform fmt`
- ✅ Validate before commit: `terraform validate`
- ✅ Use meaningful commit messages
- ✅ Test changes in development first

### **Security**
- ✅ Never commit secrets to Git
- ✅ Use GitHub Secrets for credentials
- ✅ Review security scan results
- ✅ Follow least privilege principle

### **Deployment**
- ✅ Review plans before applying
- ✅ Use feature branches for changes
- ✅ Monitor deployment progress
- ✅ Verify health checks pass

### **Monitoring**
- ✅ Check CloudWatch dashboards
- ✅ Monitor Sentry for errors
- ✅ Review application logs
- ✅ Set up appropriate alerts

## 🎉 **Success Indicators**

After successful deployment, verify:

1. ✅ **Pipeline Status**: Green checkmarks in Actions
2. ✅ **Application**: https://greyzonerentals.com responds
3. ✅ **Health Check**: `/api/test-db` returns success
4. ✅ **CloudWatch**: Metrics flowing to dashboard
5. ✅ **Sentry**: Error tracking operational
6. ✅ **Logs**: CloudWatch logs receiving data

---

**Need Help?** 
- 📖 Check this guide first
- 🔍 Review GitHub Actions logs
- 📊 Monitor CloudWatch dashboards
- 🐛 Check Sentry for application errors

**Last Updated**: January 2024  
**Pipeline Version**: 2.0 (Enhanced Monitoring) 