# SMS Seller Connect EC2 Module

This module creates an EC2 instance that runs the SMS Seller Connect application using Docker Compose with separate frontend and backend containers.

## Architecture

The module creates:
- **EC2 Instance**: Amazon Linux 2023 with Docker and Docker Compose
- **Security Groups**: Configured for SSH (22), Frontend (8082), and Backend (8900)
- **S3 Integration**: Uploads and downloads Docker Compose configuration files
- **Monitoring**: CloudWatch logging and automated health checks
- **Maintenance**: Automated service monitoring and restart capabilities

## Files Structure

```
modules/ec2/
├── docker-compose.yml      # Docker Compose configuration
├── .env.template          # Environment variables template
├── scripts/
│   ├── user_data.sh       # EC2 bootstrap script
│   └── maintenance.sh     # Service monitoring script
├── main.tf               # Main Terraform configuration
├── variables.tf          # Input variables
├── outputs.tf           # Output values
├── data.tf              # Data sources
├── locals.tf            # Local values
└── README.md            # This file
```

## Docker Compose Services

### Backend Service
- **Image**: `sms-wholesaling-backend:latest` from ECR
- **Port**: 8900
- **Health Check**: `GET /health`
- **Environment**: Database, Twilio, OpenAI, AWS configurations

### Frontend Service
- **Image**: `sms-wholesaling-frontend:latest` from ECR
- **Port**: 8082
- **Health Check**: HTTP response check
- **Dependencies**: Waits for backend to be healthy

## Deployment Process

1. **S3 Upload**: Terraform uploads Docker Compose files to S3
2. **EC2 Launch**: Instance starts with user data script
3. **Setup Phase**:
   - Install Docker, Docker Compose, and dependencies
   - Download configuration files from S3
   - Create environment file from template
   - Login to ECR and pull latest images
4. **Service Start**: Docker Compose starts both services
5. **Monitoring Setup**: Configure health checks and maintenance

## Environment Variables

The `.env.template` file is populated with these variables:

| Variable | Source | Description |
|----------|--------|-------------|
| `DB_HOST` | Terraform | PostgreSQL database host |
| `DB_PASSWORD` | Terraform | Database password |
| `TWILIO_ACCOUNT_SID` | Terraform | Twilio Account SID |
| `OPENAI_API_KEY` | Terraform | OpenAI API key |
| `SECRET_KEY` | Terraform | Flask application secret |
| `AWS_REGION` | Terraform | AWS region |

## Monitoring & Maintenance

### Health Checks
- **Backend**: Checks `/health` endpoint every 30 seconds
- **Frontend**: Checks HTTP response every 30 seconds
- **Maintenance Script**: Runs every 5 minutes via cron

### Maintenance Features
- Automatic service restart on failure
- Daily image updates at 2 AM
- Log cleanup and rotation
- Disk and memory usage monitoring

### Manual Operations

```bash
# SSH to the instance
ssh -i your-key.pem ec2-user@<instance-ip>

# Check service status
cd /app/sms-seller-connect
sudo docker-compose ps

# View logs
sudo docker-compose logs backend
sudo docker-compose logs frontend

# Manual maintenance
sudo sms-maintenance check    # Health check
sudo sms-maintenance update   # Update images
sudo sms-maintenance restart  # Restart services
```

## Security Configuration

### Security Groups
- **Port 22**: SSH access (restrict to your IP)
- **Port 8082**: Frontend web interface
- **Port 8900**: Backend API
- **Outbound**: Full internet access for ECR/updates

### IAM Permissions
The EC2 instance requires:
- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:GetDownloadUrlForLayer`
- `ecr:BatchGetImage`
- `s3:GetObject` (for configuration files)
- `logs:CreateLogGroup`
- `logs:CreateLogStream`
- `logs:PutLogEvents`

## Troubleshooting

### Common Issues

1. **Services not starting**:
   ```bash
   cd /app/sms-seller-connect
   sudo docker-compose logs
   ```

2. **Environment variables not set**:
   ```bash
   cat /app/sms-seller-connect/.env
   ```

3. **ECR login issues**:
   ```bash
   sudo aws ecr get-login-password --region us-east-1 | \
   sudo docker login --username AWS --password-stdin 522814698925.dkr.ecr.us-east-1.amazonaws.com
   ```

### Log Locations
- **Setup Logs**: `/var/log/sms-seller-connect-setup.log`
- **Maintenance Logs**: `/var/log/sms-seller-connect-maintenance.log`
- **Application Logs**: `/app/logs/`
- **Docker Logs**: `sudo docker-compose logs`

## Updating the Application

### New Image Deployment
1. Push new images to ECR with `:latest` tag
2. Wait for automatic update (daily at 2 AM) or run manually:
   ```bash
   sudo sms-maintenance update
   ```

### Configuration Changes
1. Update `docker-compose.yml` or `.env.template`
2. Run `terraform apply` to upload new files
3. On EC2 instance:
   ```bash
   cd /app/sms-seller-connect
   sudo aws s3 cp s3://your-bucket/docker-compose/docker-compose.yml ./
   sudo docker-compose up -d
   ```

## Resource Requirements

### Recommended Instance Types
- **Development**: `t3.small` (2 vCPU, 2 GB RAM)
- **Production**: `t3.medium` (2 vCPU, 4 GB RAM) or larger
- **High Load**: `c5.large` (2 vCPU, 4 GB RAM) or larger

### Storage
- **Root Volume**: 20 GB minimum
- **Log Storage**: `/app/logs` for application logs
- **Docker Storage**: Managed by Docker daemon 