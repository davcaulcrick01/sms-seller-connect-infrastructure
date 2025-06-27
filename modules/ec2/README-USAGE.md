# SMS Seller Connect EC2 Module - Quick Usage Guide

## 🚀 Ready to Deploy

This EC2 module is configured with all your actual values from the `.env` file and is ready to deploy.

## ✅ What's Configured

### **Frontend & Backend Images**
- ✅ Frontend: `${FRONTEND_IMAGE}` → `sms-wholesaling-frontend:latest`
- ✅ Backend: `${BACKEND_IMAGE}` → `sms-wholesaling-backend:latest`

### **Environment Variables**
- ✅ All values from your `.env` file are included
- ✅ Database: `ec2-54-237-212-127.compute-1.amazonaws.com:5437`
- ✅ Twilio: Account SID, Auth Token, Phone Number
- ✅ OpenAI: API Key, Model (gpt-4o), Temperature (0.3)
- ✅ SendGrid: API Key, From Email
- ✅ AWS: Access Keys, S3 Bucket

### **Architecture**
```
Internet → Route53 → ALB (HTTPS) → EC2 Instance → Nginx → Docker Containers
                                                    ├── SMS Backend (8900)
                                                    ├── SMS Frontend (8082)
                                                    └── Nginx Proxy (80)
```

## 🔧 Quick Deploy

1. **Update Required Values** in `terraform.tfvars`:
   ```bash
   # Update these 3 values:
   ssh_public_key = "ssh-rsa AAAAB3... your-actual-ssh-key"
   domain_zone_name = "your-actual-domain.com"
   acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/your-cert"
   ```

2. **Deploy**:
   ```bash
   cd /Users/davidcaulcrick/Downloads/app/Infrastructure/sms-seller-connect/modules/ec2
   terraform init
   terraform plan
   terraform apply
   ```

## 📋 Prerequisites

### **1. Domain & Certificate**
```bash
# Create ACM certificate for your domain
aws acm request-certificate \
    --domain-name "*.yourdomain.com" \
    --domain-name "yourdomain.com" \
    --validation-method DNS \
    --region us-east-1
```

### **2. SSH Key**
```bash
# Generate SSH key if needed
ssh-keygen -t rsa -b 4096 -f ~/.ssh/sms-key
cat ~/.ssh/sms-key.pub  # Copy this to terraform.tfvars
```

### **3. VPC & Subnets**
Make sure these exist in your AWS account:
- VPC: `Grey-VPC`
- Subnet 1: `Grey-private-subnet`
- Subnet 2: `Grey-public-subnet` (in different AZ for ALB)

## 🔍 Verify Deployment

After deployment:

```bash
# Get instance IP
terraform output instance_public_ip

# Test ALB health check
curl -I http://$(terraform output -raw instance_public_ip)/alb-health

# Test applications (after DNS propagates)
curl -I https://sms.yourdomain.com
curl -I https://api.sms.yourdomain.com/health
```

## 🐳 Container Management

SSH to instance and manage containers:
```bash
# SSH to instance
ssh -i ~/.ssh/sms-key ec2-user@$(terraform output -raw instance_public_ip)

# View containers
docker-compose ps

# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Update images
docker-compose pull && docker-compose up -d
```

## 📊 Monitoring

- **CloudWatch Logs**: `/aws/ec2/sms-seller-connect`
- **Container Logs**: `docker-compose logs`
- **Nginx Logs**: `/opt/apps/logs/nginx/`
- **Health Checks**: ALB monitors `/alb-health`

## 🔧 Troubleshooting

### Container Issues
```bash
# Check container status
docker-compose ps

# View specific service logs
docker-compose logs sms_backend
docker-compose logs sms_frontend
docker-compose logs nginx

# Restart problematic service
docker-compose restart sms_backend
```

### DNS Issues
```bash
# Check Route53 records
aws route53 list-resource-record-sets --hosted-zone-id YOUR_ZONE_ID

# Test DNS resolution
nslookup sms.yourdomain.com
```

### ALB Issues
```bash
# Check ALB target health
aws elbv2 describe-target-health --target-group-arn $(terraform output -raw target_group_arn)
```

---

**Ready to deploy!** Just update the 3 required values in `terraform.tfvars` and run `terraform apply`. 