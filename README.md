# SMS Seller Connect Infrastructure

This directory contains the Terraform infrastructure configuration for the SMS Seller Connect application, which runs both frontend and backend containers from ECR using Docker Compose on EC2.

## Architecture Overview

The infrastructure deploys:
- **EC2 Instance**: Runs Docker Compose with frontend and backend containers
- **ECR Integration**: Pulls latest images from `sms-wholesaling-frontend` and `sms-wholesaling-backend` repositories
- **CloudWatch Monitoring**: Comprehensive logging and metrics
- **Security Groups**: Properly configured for web traffic
- **S3 Storage**: For application assets and logs
- **Route53**: DNS configuration (optional)

📋 **For detailed variable flow documentation, see [VARIABLE-FLOW-DOCUMENTATION.md](./VARIABLE-FLOW-DOCUMENTATION.md)**

## Prerequisites

1. **AWS CLI configured** with appropriate permissions
2. **Terraform installed** (version 1.0+)
3. **ECR repositories** with pushed frontend and backend images:
   - `522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-frontend:latest`
   - `522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-backend:latest`
4. **Database**: PostgreSQL instance with `sms_blaster` database
5. **Twilio Account**: For SMS functionality
6. **OpenAI API Key**: For AI processing

## Quick Start

### 1. Configure Variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform.tfvars` with your actual values:

```hcl
# Database Configuration
db_host     = "your-postgres-host.amazonaws.com"
db_password = "your-secure-password"

# Twilio Configuration
twilio_account_sid  = "ACxxxxxxxxxxxxxxxxx"
twilio_auth_token   = "your-twilio-token"
twilio_phone_number = "+1234567890"

# OpenAI Configuration
openai_api_key = "sk-xxxxxxxxxxxxxxxx"

# Application Security
secret_key     = "your-32-char-flask-secret"
jwt_secret_key = "your-32-char-jwt-secret"
```

### 2. Deploy Infrastructure

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

### 3. Verify Deployment

After deployment, the EC2 instance will:
1. Install Docker and Docker Compose
2. Login to ECR
3. Pull latest frontend and backend images
4. Start services with Docker Compose
5. Set up monitoring and health checks

Access your application:
- **Frontend**: `http://<ec2-public-ip>:8082`
- **Backend API**: `http://<ec2-public-ip>:8900`

## Application Components

### Frontend Container
- **Image**: `sms-wholesaling-frontend:latest`
- **Port**: 8082
- **Technology**: React/Vite application
- **Environment**: 
  - `VITE_API_URL=http://localhost:8900`

### Backend Container
- **Image**: `sms-wholesaling-backend:latest`
- **Port**: 8900
- **Technology**: FastAPI/Flask application
- **Environment**: Database, Twilio, OpenAI configurations

## Docker Compose Configuration

The EC2 instance runs Docker Compose with:

```yaml
services:
  backend:
    image: 522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-backend:latest
    ports: ["8900:8900"]
    environment: [database, twilio, openai configs]
    
  frontend:
    image: 522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-frontend:latest
    ports: ["8082:8082"]
    depends_on: [backend]
```

## Monitoring & Maintenance

### CloudWatch Logs
- **Setup Logs**: `/aws/ec2/sms-seller-connect`
- **Application Logs**: Container logs via Docker
- **System Metrics**: CPU, Memory, Disk usage

### Health Checks
- **Backend**: `GET /health` endpoint
- **Frontend**: HTTP response check
- **Automatic Restart**: Unhealthy containers restart automatically

### Maintenance Script
A cron job runs every 15 minutes to:
- Check service health
- Restart failed containers
- Clean up old logs

## Security Configuration

### Security Groups
- **Port 22**: SSH access (restricted to your IP)
- **Port 8082**: Frontend web access
- **Port 8900**: Backend API access
- **Outbound**: All traffic allowed for ECR/internet access

### IAM Permissions
The EC2 instance has permissions for:
- ECR image pulling
- CloudWatch logging
- S3 access for assets

## Troubleshooting

### Common Issues

1. **Containers not starting**:
   ```bash
   ssh -i your-key.pem ec2-user@<ec2-ip>
   cd /app/sms-seller-connect
   sudo docker-compose logs
   ```

2. **ECR login issues**:
   ```bash
   sudo aws ecr get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin 522814698925.dkr.ecr.us-east-1.amazonaws.com
   ```

3. **Environment variables not set**:
   ```bash
   cat /app/sms-seller-connect/.env
   ```

### Log Locations
- **User Data Script**: `/var/log/sms-seller-connect-setup.log`
- **Application Logs**: `/app/logs/`
- **Docker Logs**: `sudo docker-compose logs`

## Updating the Application

### Deploy New Images
1. Push new images to ECR with `:latest` tag
2. On EC2 instance:
   ```bash
   cd /app/sms-seller-connect
   sudo docker-compose pull
   sudo docker-compose up -d
   ```

### Infrastructure Updates
1. Update Terraform configuration
2. Run `terraform plan` and `terraform apply`
3. For user data changes, terminate and recreate EC2 instance

## Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_HOST` | PostgreSQL host | `mydb.amazonaws.com` |
| `DB_PASSWORD` | Database password | `SecurePassword123!` |
| `TWILIO_ACCOUNT_SID` | Twilio Account SID | `ACxxxxxxxxxxxxxxx` |
| `TWILIO_AUTH_TOKEN` | Twilio Auth Token | `your-auth-token` |
| `TWILIO_PHONE_NUMBER` | SMS phone number | `+1234567890` |
| `OPENAI_API_KEY` | OpenAI API key | `sk-xxxxxxxxxxxxxxx` |
| `SECRET_KEY` | Flask secret key | `32-character-string` |
| `JWT_SECRET_KEY` | JWT signing key | `32-character-string` |

## Cost Optimization

- **Instance Type**: Start with `t3.medium`, scale as needed
- **EBS Volumes**: Use `gp3` for cost efficiency
- **CloudWatch**: Monitor log retention periods
- **S3**: Use lifecycle policies for old logs

## Support

For issues:
1. Check CloudWatch logs
2. Review EC2 user data execution
3. Verify ECR image availability
4. Confirm environment variables are set correctly

## Architecture Diagram

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Internet      │    │     Route53      │    │   CloudWatch    │
│   Users         │────│   (Optional)     │    │   Monitoring    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                        EC2 Instance                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Frontend      │  │    Backend      │  │   Monitoring    │ │
│  │   (Port 8082)   │  │   (Port 8900)   │  │   & Logs        │ │
│  │   React/Vite    │──│   FastAPI       │  │                 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│      ECR        │    │   PostgreSQL     │    │      S3         │
│   Repositories  │    │   Database       │    │   Storage       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
``` 