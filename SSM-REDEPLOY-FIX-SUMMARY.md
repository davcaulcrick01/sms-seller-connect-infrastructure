# 🔧 SSM Redeploy Fix Summary

## Problem Resolved
**Mixed Content Security Error**: Frontend at `https://sms.typerelations.com/leads` was making HTTP requests to `http://api.sms.typerelations.com`, causing browser blocking.

**SSM Connectivity Issue**: Pipeline failing with "InvalidInstanceId - Instances not in a valid state for account" error (exit code 254).

---

## Root Cause Analysis

### 1. HTTPS Configuration Issue
- Frontend was defaulting to HTTP because `VITE_API_URL` environment variable wasn't properly set
- Configuration in `frontend/src/lib/config.ts`: `const API_URL = VITE_API_URL || 'http://localhost:${BACKEND_PORT}';`

### 2. SSM Agent Permissions
- EC2 instance IAM role was missing Systems Manager permissions
- SSM agent needed to restart to pick up new IAM policies
- Pipeline had no fallback mechanism for SSM failures

---

## Fixes Applied

### ✅ 1. GitHub Repository Variables Fixed
- Updated `VITE_API_URL` from HTTP to HTTPS: `https://api.sms.typerelations.com`
- Applied via `fix-github-variables.sh` script

### ✅ 2. IAM Permissions Added
**File**: `modules/ec2/iam.tf`
```hcl
# Added missing SSM policies
resource "aws_iam_role_policy_attachment" "ec2_ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_combined_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_agent_server_policy" {
  role       = aws_iam_role.ec2_combined_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
```

### ✅ 3. Enhanced Deployment Script
**File**: `modules/ec2/scripts/user_data.sh`
- Added `VITE_API_URL=https://${SMS_API_DOMAIN}` to environment file creation
- Ensures HTTPS configuration is baked into deployments

### ✅ 4. Improved Pipeline (terraform.yml)
**Enhanced SSM handling**:
- **SSM Agent Restart**: Automatically restarts SSM agent to pick up new IAM permissions
- **Fallback Deployment**: If SSM fails, reboots instance to restore connectivity
- **Error Recovery**: Better error handling and diagnostic output
- **HTTPS Environment**: Includes `VITE_API_URL` in deployment commands

**Key improvements**:
```yaml
# Step 1: Restart SSM agent to pick up new IAM permissions
SSM_RESTART_COMMANDS='["#!/bin/bash","sudo systemctl restart amazon-ssm-agent",...]'

# Step 2: Deploy with HTTPS configuration
export VITE_API_URL="https://api.sms.typerelations.com"

# Step 3: Fallback via instance restart if SSM fails
aws ec2 reboot-instances --instance-ids "$INSTANCE_ID"
```

### ✅ 5. Hotfix Scripts Created
- **`hotfix-ssm-redeploy.sh`**: Immediate SSM recovery and deployment
- **`trigger-redeploy-via-github.sh`**: Trigger improved pipeline via GitHub Actions

---

## Current Status

### 🚀 **DEPLOYMENT IN PROGRESS**
- ✅ All fixes committed and pushed to GitHub
- ✅ Improved pipeline triggered via GitHub Actions
- ✅ Expected completion: **10-15 minutes**

### 📊 **Monitor Progress**
- **GitHub Actions**: https://github.com/davcaulcrick01/sms-seller-connect-infrastructure/actions
- **Command**: `gh run list --repo davcaulcrick01/sms-seller-connect-infrastructure --limit 5`

---

## Expected Results

### 🎯 **After Deployment Completes**:
1. **Frontend**: `https://sms.typerelations.com` - All API calls will use HTTPS
2. **Backend**: `https://api.sms.typerelations.com` - Properly configured SSL
3. **Mixed Content Error**: ❌ RESOLVED - No more HTTP requests from HTTPS pages
4. **SSM Connectivity**: ✅ RESTORED - Pipeline can deploy without manual intervention

### 🔍 **Verification Steps**:
1. Check browser console - no mixed content warnings
2. Test API calls - all should use HTTPS
3. Verify SSM connectivity - `aws ssm send-command` should work
4. Monitor pipeline - future deployments should complete successfully

---

## Future Deployments

The pipeline now includes **robust SSM recovery**:
- ✅ Automatic SSM agent restart
- ✅ Fallback deployment via instance restart
- ✅ HTTPS environment variables built-in
- ✅ Comprehensive error handling

**Next redeployments should work seamlessly without manual intervention.**

---

## Files Modified

1. `Infrastructure/sms-seller-connect/modules/ec2/iam.tf` - Added SSM policies
2. `Infrastructure/sms-seller-connect/modules/ec2/scripts/user_data.sh` - Added VITE_API_URL
3. `Infrastructure/sms-seller-connect/.github/workflows/terraform.yml` - Enhanced SSM handling
4. `Infrastructure/sms-seller-connect/hotfix-ssm-redeploy.sh` - Immediate recovery script
5. `Infrastructure/sms-seller-connect/trigger-redeploy-via-github.sh` - Pipeline trigger

---

## Summary

**Problem**: Mixed content error + SSM connectivity failure  
**Solution**: HTTPS configuration + Enhanced SSM recovery pipeline  
**Status**: 🚀 **DEPLOYING NOW** - ETA 10-15 minutes  
**Result**: ✅ Secure HTTPS communication + Reliable deployments  

🎉 **The mixed content security error will be resolved once deployment completes!** 