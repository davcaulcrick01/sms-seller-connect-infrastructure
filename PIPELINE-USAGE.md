# SMS Seller Connect Pipeline Usage Guide

This document explains how to use the updated CI/CD pipeline for SMS Seller Connect, including the new redeployment features that allow updating the application without destroying the EC2 instance.

## 🚀 Available Actions

The pipeline supports the following actions via GitHub Actions workflow dispatch:

### 1. **Plan** (Default)
- **Purpose**: Preview infrastructure changes
- **Use Case**: Review what will be created/modified before applying
- **Safe**: Yes, read-only operation

### 2. **Apply**
- **Purpose**: Deploy/update infrastructure
- **Use Case**: Create new infrastructure or apply infrastructure changes
- **Safe**: Requires manual approval in production

### 3. **Destroy**
- **Purpose**: Destroy all infrastructure
- **Use Case**: Tear down environment completely
- **Safe**: ⚠️ **DESTRUCTIVE** - Requires manual approval

### 4. **Format**
- **Purpose**: Auto-format Terraform files
- **Use Case**: Maintain consistent code formatting
- **Safe**: Yes, only formatting changes

### 5. **🆕 Redeploy**
- **Purpose**: Update application without destroying EC2 instance
- **Use Case**: Deploy new application versions, update environment variables
- **Safe**: Yes, preserves infrastructure and creates backups

### 6. **🆕 Verify Secrets**
- **Purpose**: Verify all GitHub secrets and variables are properly configured
- **Use Case**: Troubleshoot configuration issues, validate setup
- **Safe**: Yes, read-only verification

## 🔄 How to Use the Redeploy Feature

The **redeploy** action is the recommended way to update your application without infrastructure changes.

### When to Use Redeploy:
- ✅ New application code versions
- ✅ Environment variable updates
- ✅ Configuration changes
- ✅ Docker image updates
- ✅ Fixing application issues

### When NOT to Use Redeploy:
- ❌ Infrastructure changes (use `apply` instead)
- ❌ Security group modifications
- ❌ Instance type changes
- ❌ Network configuration changes

### Steps to Redeploy:

1. **Go to GitHub Actions**
   - Navigate to your repository
   - Click on "Actions" tab
   - Select "SMS Seller Connect - Terraform CI/CD Pipeline"

2. **Run Workflow**
   - Click "Run workflow"
   - Select **Action**: `redeploy`
   - Select **Environment**: `prod` (or your target environment)
   - Click "Run workflow"

3. **Monitor Progress**
   - The pipeline will:
     - ✅ Upload the redeployment script to S3
     - ✅ Find your EC2 instance
     - ✅ Execute redeployment via AWS SSM
     - ✅ Verify application health
     - ✅ Provide detailed results

## 🔐 GitHub Secrets & Variables Verification

Use the **verify-secrets** action to ensure all configuration is properly set.

### Required Secrets:
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `SSH_PUBLIC_KEY` - SSH public key for EC2 access
- `DB_HOST` - Database host
- `DB_USER` - Database username
- `DB_PASSWORD` - Database password
- `FLASK_SECRET_KEY` - Flask application secret
- `JWT_SECRET_KEY` - JWT signing secret
- `TWILIO_ACCOUNT_SID` - Twilio account identifier
- `TWILIO_AUTH_TOKEN` - Twilio authentication token
- `TWILIO_PHONE_NUMBER` - Twilio phone number
- `OPENAI_API_KEY` - OpenAI API key
- `SENDGRID_API_KEY` - SendGrid API key
- `NGROK_AUTH_TOKEN` - Ngrok authentication token
- `HOT_LEAD_SMS_RECIPIENTS` - SMS recipients for hot leads

### Required Variables:
- `BACKEND_IMAGE` - Docker image for backend (optional, has fallback)
- `FRONTEND_IMAGE` - Docker image for frontend (optional, has fallback)
- `SMS_FRONTEND_DOMAIN` - Frontend domain (optional, has fallback)
- `SMS_API_DOMAIN` - API domain (optional, has fallback)
- `SENDGRID_FROM_EMAIL` - SendGrid from email (optional, has fallback)
- `DB_PORT` - Database port (optional, defaults to 5437)
- `DB_NAME` - Database name (optional, defaults to sms_blast)

## 🛠️ Redeployment Process Details

### What the Redeployment Does:

1. **Backup Current Configuration**
   - Creates timestamped backup in `/app/backups/`
   - Preserves current setup for rollback

2. **Download Fresh Configuration**
   - Downloads latest config files from S3
   - Updates Docker Compose, Nginx, health checks

3. **Update Environment Variables**
   - Creates new `.env` file with all current variables
   - Ensures all secrets are properly set

4. **Stop/Start Services**
   - Gracefully stops existing containers
   - Pulls latest Docker images
   - Starts services with new configuration

5. **Verify Health**
   - Tests application endpoints
   - Verifies container status
   - Provides detailed status report

### Rollback Process:
If redeployment fails, you can manually rollback:

```bash
# SSH into EC2 instance
ssh -i your-key.pem ec2-user@INSTANCE_IP

# List available backups
ls -la /app/backups/

# Restore from backup (replace with actual backup directory)
sudo cp -r /app/backups/20250630_160000/sms-seller-connect /app/
cd /app/sms-seller-connect
sudo docker-compose up -d
```

## 📊 Monitoring and Logs

### View Redeployment Logs:
```bash
# SSH into EC2 instance
ssh -i your-key.pem ec2-user@INSTANCE_IP

# View redeployment logs
sudo tail -f /var/log/sms-redeploy.log

# View application logs
cd /app/sms-seller-connect
sudo docker-compose logs -f
```

### Health Check Endpoints:
- **ALB Health**: `http://YOUR_ALB_DNS/alb-health`
- **Backend Health**: `http://YOUR_DOMAIN:8900/health`
- **Frontend**: `http://YOUR_DOMAIN:8082`

## 🚨 Troubleshooting

### Common Issues:

1. **"No running EC2 instance found"**
   - Check if instance is running: `aws ec2 describe-instances --filters "Name=tag:Name,Values=sms-seller-connect-prod-ec2"`
   - Verify environment name matches

2. **"Missing required environment variables"**
   - Run `verify-secrets` action to check configuration
   - Update missing secrets/variables in GitHub repository settings

3. **"SSM command failed"**
   - Check if SSM agent is running on EC2 instance
   - Verify IAM permissions for SSM

4. **"Health check failed"**
   - Check Docker container status: `sudo docker-compose ps`
   - Review application logs: `sudo docker-compose logs`

### Manual Redeployment:
If the pipeline fails, you can run the redeployment manually:

```bash
# SSH into EC2 instance
ssh -i your-key.pem ec2-user@INSTANCE_IP

# Download and run redeployment script
aws s3 cp s3://sms-seller-connect-bucket/scripts/redeploy-application.sh /tmp/redeploy.sh
chmod +x /tmp/redeploy.sh

# Set required environment variables (example)
export BACKEND_IMAGE="522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-backend:latest"
export FRONTEND_IMAGE="522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-frontend:latest"
# ... set all other required variables

# Run redeployment
/tmp/redeploy.sh
```

## 🔒 Security Notes

- All secrets are handled securely via GitHub secrets
- Environment files have restricted permissions (600)
- Backups are created before any changes
- SSM is used for secure command execution
- No sensitive data is logged in pipeline output

## 📞 Support

For issues with the pipeline:
1. Check the GitHub Actions logs
2. Run `verify-secrets` to check configuration
3. Review EC2 instance logs
4. Check this documentation for troubleshooting steps 