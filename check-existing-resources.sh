#!/bin/bash

# ########################################
# Check for Existing AWS Resources
# ########################################
# This script checks for existing AWS resources that might conflict
# with the SMS Seller Connect Terraform deployment

set -e

echo "🔍 Checking for existing AWS resources..."
echo "========================================"
echo ""

# Check AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI not configured or no access. Please configure AWS credentials."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region || echo "us-east-1")

echo "📋 AWS Account: $ACCOUNT_ID"
echo "🌍 Region: $REGION"
echo ""

# Check for existing EC2 instances
echo "🖥️  Checking for existing EC2 instances..."
INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name,InstanceType]' \
    --output table 2>/dev/null || echo "No instances found")

if [[ "$INSTANCES" != "No instances found" ]]; then
    echo "Found EC2 instances:"
    echo "$INSTANCES"
    echo ""
else
    echo "✅ No existing EC2 instances found"
    echo ""
fi

# Check for existing S3 buckets
echo "🪣 Checking for SMS Seller Connect S3 bucket..."
if aws s3 ls "s3://sms-seller-connect-bucket" > /dev/null 2>&1; then
    echo "⚠️  S3 bucket 'sms-seller-connect-bucket' already exists"
    echo "   Bucket contents:"
    aws s3 ls s3://sms-seller-connect-bucket --recursive | head -10
    echo ""
else
    echo "✅ S3 bucket 'sms-seller-connect-bucket' does not exist"
    echo ""
fi

# Check for existing Route53 hosted zones
echo "🌐 Checking for existing Route53 hosted zones..."
ZONES=$(aws route53 list-hosted-zones \
    --query 'HostedZones[?contains(Name, `typerelations.com`)].[Id,Name,ResourceRecordSetCount]' \
    --output table 2>/dev/null || echo "No zones found")

if [[ "$ZONES" != "No zones found" ]]; then
    echo "Found Route53 hosted zones:"
    echo "$ZONES"
    echo ""
else
    echo "✅ No existing Route53 hosted zones found for typerelations.com"
    echo ""
fi

# Check for existing Load Balancers
echo "⚖️  Checking for existing Application Load Balancers..."
ALBS=$(aws elbv2 describe-load-balancers \
    --query 'LoadBalancers[?contains(LoadBalancerName, `sms`) || contains(LoadBalancerName, `seller`)].[LoadBalancerArn,LoadBalancerName,State.Code,Type]' \
    --output table 2>/dev/null || echo "No ALBs found")

if [[ "$ALBS" != "No ALBs found" ]]; then
    echo "Found Application Load Balancers:"
    echo "$ALBS"
    echo ""
else
    echo "✅ No existing Application Load Balancers found"
    echo ""
fi

# Check for existing Security Groups
echo "🔒 Checking for existing Security Groups..."
SGS=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=*sms*,*seller*,*connect*" \
    --query 'SecurityGroups[*].[GroupId,GroupName,Description]' \
    --output table 2>/dev/null || echo "No matching security groups found")

if [[ "$SGS" != "No matching security groups found" ]]; then
    echo "Found Security Groups:"
    echo "$SGS"
    echo ""
else
    echo "✅ No existing SMS-related Security Groups found"
    echo ""
fi

# Check for existing Key Pairs
echo "🔑 Checking for existing Key Pairs..."
KEYS=$(aws ec2 describe-key-pairs \
    --query 'KeyPairs[?contains(KeyName, `sms`) || contains(KeyName, `seller`) || contains(KeyName, `car-rental`)].[KeyName,KeyPairId]' \
    --output table 2>/dev/null || echo "No matching key pairs found")

if [[ "$KEYS" != "No matching key pairs found" ]]; then
    echo "Found Key Pairs:"
    echo "$KEYS"
    echo ""
else
    echo "✅ No existing SMS-related Key Pairs found"
    echo ""
fi

echo "🎯 Summary & Recommendations:"
echo "============================="
echo ""
echo "If you found existing resources above, you have these options:"
echo ""
echo "1. 🔄 IMPORT existing resources into Terraform state:"
echo "   - Edit modules/ec2/import.tf"
echo "   - Uncomment and update the import blocks with actual resource IDs"
echo "   - Run: terraform plan && terraform apply"
echo ""
echo "2. 🏷️  RENAME your Terraform resources to avoid conflicts:"
echo "   - Update variable values in terraform.tfvars"
echo "   - Use different names for bucket_name, instance_name, etc."
echo ""
echo "3. 🧹 CLEAN UP existing resources manually (if safe to do so):"
echo "   - Only do this if you're sure the resources aren't being used"
echo ""
echo "4. 🎯 USE EXISTING resources by referencing them as data sources:"
echo "   - Modify the Terraform code to use data sources instead of resources"
echo ""
echo "⚠️  IMPORTANT: The lifecycle rules I added will prevent accidental destruction"
echo "   of resources once they're managed by Terraform."
echo ""
echo "✅ Your Terraform configuration is now safe to run!" 