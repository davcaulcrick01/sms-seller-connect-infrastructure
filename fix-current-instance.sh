#!/bin/bash

echo "🔧 Manual Fix Script for Current EC2 Instance"
echo "=============================================="

# Set the instance IP (from your logs: ip-10-0-5-190)
INSTANCE_IP="10.0.5.190"  # Private IP from logs
SSH_KEY="./modules/ec2/car-rental-key.pem"

echo "📋 This script will:"
echo "1. SSH into the EC2 instance"
echo "2. Create proper environment variables"
echo "3. Restart Docker Compose with correct configuration"
echo ""

# Create the fix script that will run on the EC2 instance
cat > /tmp/ec2-fix.sh << 'EOF'
#!/bin/bash

echo "🔧 Fixing environment variables on EC2 instance..."

# Navigate to the app directory
cd /app/sms-seller-connect

# Create proper .env file with actual values
echo "📝 Creating .env file with proper values..."
cat > .env << 'ENVEOF'
# Docker Images
BACKEND_IMAGE=522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-backend:latest
FRONTEND_IMAGE=522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-frontend:latest

# Domain Configuration  
SMS_API_DOMAIN=api.sms.typerelations.com
SMS_FRONTEND_DOMAIN=sms.typerelations.com

# Database Configuration
DB_HOST=database-1.cluster-ctpyc0i9lnnk.us-east-1.rds.amazonaws.com
DB_PORT=5437
DB_NAME=sms_blast
DB_USER=postgres
DB_PASSWORD=your_db_password_here

# Application Configuration
FLASK_SECRET_KEY=your_flask_secret_here
JWT_SECRET_KEY=your_jwt_secret_here
SECRET_KEY=your_flask_secret_here

# Twilio Configuration
TWILIO_ACCOUNT_SID=your_twilio_account_sid_here
TWILIO_AUTH_TOKEN=your_twilio_auth_token_here
TWILIO_PHONE_NUMBER=your_twilio_phone_here

# OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_MODEL=gpt-4o
OPENAI_TEMPERATURE=0.3

# SendGrid Configuration
SENDGRID_API_KEY=your_sendgrid_api_key_here
SENDGRID_FROM_EMAIL=noreply@typerelations.com

# AWS Configuration
AWS_ACCESS_KEY_ID=your_aws_access_key_here
AWS_SECRET_ACCESS_KEY=your_aws_secret_key_here
AWS_REGION=us-east-1
S3_BUCKET_NAME=grey-database-bucket

# Hot Lead Configuration
HOT_LEAD_EMAIL_RECIPIENTS=admin@greyzonesolutions.com
HOT_LEAD_SMS_RECIPIENTS=+14693785661

# Rate Limiting
RATE_LIMIT_PER_MINUTE=60
RATE_LIMIT_BURST=10

# Session Configuration
SESSION_TIMEOUT_MINUTES=60
REMEMBER_ME_DAYS=30

# File Upload Configuration
MAX_FILE_SIZE_MB=10
ALLOWED_FILE_TYPES=pdf,jpg,jpeg,png,doc,docx,csv

# CloudWatch Configuration
CLOUDWATCH_LOG_GROUP=/aws/ec2/sms-seller-connect
CLOUDWATCH_LOG_STREAM=application

# Environment
ENVIRONMENT=prod
ENVEOF

echo "✅ .env file created"

# Stop existing containers
echo "🛑 Stopping existing containers..."
sudo docker-compose down 2>/dev/null || true

# Remove old containers
echo "🗑️ Removing old containers..."
sudo docker container prune -f

# Pull latest images
echo "⬇️ Pulling latest images..."
sudo docker-compose pull

# Start services
echo "🚀 Starting services..."
sudo docker-compose up -d

# Check status
echo "📊 Container status:"
sudo docker-compose ps

# Check logs
echo "📋 Recent logs:"
sudo docker-compose logs --tail=10

echo "✅ Fix completed!"
EOF

# Copy the script to the instance and run it
echo "📤 Copying fix script to EC2 instance..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no /tmp/ec2-fix.sh ec2-user@$INSTANCE_IP:/tmp/

echo "🔧 Running fix script on EC2 instance..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP "chmod +x /tmp/ec2-fix.sh && sudo /tmp/ec2-fix.sh"

echo ""
echo "✅ Manual fix completed!"
echo "🌐 Test the application at: https://sms.typerelations.com"
echo ""
echo "⚠️  Note: This is a temporary fix. The values in the .env file need to be"
echo "   updated with actual secrets from your GitHub repository secrets." 