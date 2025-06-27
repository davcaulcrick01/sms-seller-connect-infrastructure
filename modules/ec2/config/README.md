# SMS Seller Connect Configuration Files

This directory contains the configuration files that are uploaded to S3 and used by the EC2 instance during bootstrap.

## Files Overview

### `docker-compose.yml`
- **Purpose**: Orchestrates all SMS Seller Connect services
- **Services Included**:
  - `sms_backend`: Python Flask API (port 8900)
  - `sms_frontend`: React application (port 8082)
  - `nginx`: Reverse proxy and load balancer (port 80)
  - `health_check`: ALB health monitoring service (port 8888)
- **Features**: Health checks, logging, restart policies, networking

### `nginx.conf`
- **Purpose**: Nginx reverse proxy configuration
- **Features**:
  - Domain-based routing (frontend vs API)
  - ALB health check endpoint (`/alb-health`)
  - Rate limiting and security headers
  - SSL termination handling
  - Load balancing between services

### `.env.template`
- **Purpose**: Environment variable template populated by Terraform
- **Contains**:
  - Database connection settings
  - API keys (Twilio, OpenAI, SendGrid)
  - AWS configuration
  - Application-specific settings
  - Domain and URL configurations

## Deployment Flow

1. **Terraform Upload**: These files are uploaded to S3 bucket during `terraform apply`
2. **EC2 Bootstrap**: User data script downloads files from S3
3. **Environment Setup**: `.env.template` is populated with actual values using `envsubst`
4. **Service Start**: Docker Compose starts all services using the configuration

## File Relationships

```
EC2 Instance
├── /app/sms-seller-connect/
│   ├── docker-compose.yml    (from S3)
│   ├── nginx.conf            (from S3)
│   ├── .env.template         (from S3)
│   └── .env                  (generated from template)
└── Services:
    ├── SMS Backend (Flask API)
    ├── SMS Frontend (React)
    ├── Nginx Proxy
    └── Health Check Service
```

## Updating Configuration

When modifying these files:
1. Edit the files in this directory
2. Run `terraform apply` to upload updated files to S3
3. Restart EC2 instance or manually pull updates for changes to take effect

## Security Notes

- `.env.template` contains placeholder values only
- Actual secrets are injected via Terraform variables
- All files are stored in private S3 bucket with encryption
- Environment file is created with restricted permissions (chmod 600) 