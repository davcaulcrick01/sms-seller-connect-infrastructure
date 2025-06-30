#!/bin/bash

echo "🔧 Manual EC2 Instance Fix - Run this ON the EC2 instance"
echo "========================================================="

# Navigate to the app directory
cd /app/sms-seller-connect || { echo "❌ App directory not found"; exit 1; }

echo "📝 Creating .env file with proper Docker image values..."

# Create the .env file with the correct Docker images
cat > .env << 'EOF'
# Docker Images - These are the key missing variables
BACKEND_IMAGE=522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-backend:latest
FRONTEND_IMAGE=522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-frontend:latest

# Domain Configuration  
SMS_API_DOMAIN=api.sms.typerelations.com
SMS_FRONTEND_DOMAIN=sms.typerelations.com

# Database Configuration (update with real values)
DB_HOST=database-1.cluster-ctpyc0i9lnnk.us-east-1.rds.amazonaws.com
DB_PORT=5437
DB_NAME=sms_blast
DB_USER=postgres
DB_PASSWORD=your_db_password_here

# Application Configuration (update with real values)
FLASK_SECRET_KEY=temp-secret-key-change-me
JWT_SECRET_KEY=temp-jwt-secret-change-me
SECRET_KEY=temp-secret-key-change-me

# Basic configuration
AWS_REGION=us-east-1
ENVIRONMENT=prod
OPENAI_MODEL=gpt-4o
OPENAI_TEMPERATURE=0.3

# Placeholders for other services (update as needed)
TWILIO_ACCOUNT_SID=placeholder
TWILIO_AUTH_TOKEN=placeholder
TWILIO_PHONE_NUMBER=placeholder
OPENAI_API_KEY=placeholder
SENDGRID_API_KEY=placeholder
SENDGRID_FROM_EMAIL=noreply@typerelations.com
AWS_ACCESS_KEY_ID=placeholder
AWS_SECRET_ACCESS_KEY=placeholder
S3_BUCKET_NAME=grey-database-bucket
EOF

echo "✅ .env file created with Docker image references"

# Show the file contents
echo "📄 .env file contents:"
head -10 .env

# Stop existing containers
echo "🛑 Stopping existing containers..."
sudo docker-compose down 2>/dev/null || true

# Remove problematic containers
echo "🗑️ Cleaning up containers..."
sudo docker system prune -f

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin 522814698925.dkr.ecr.us-east-1.amazonaws.com

# Pull images manually to verify they exist
echo "⬇️ Pulling backend image..."
sudo docker pull 522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-backend:latest

echo "⬇️ Pulling frontend image..."
sudo docker pull 522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-frontend:latest

# Start services
echo "🚀 Starting Docker Compose services..."
sudo docker-compose up -d

# Wait a moment
sleep 5

# Check status
echo "📊 Container status:"
sudo docker-compose ps

# Check logs for any remaining issues
echo "📋 Recent logs (last 20 lines):"
sudo docker-compose logs --tail=20

echo ""
echo "✅ Manual fix completed!"
echo "🌐 Test the application at: https://sms.typerelations.com"
echo ""
echo "📋 Next steps:"
echo "1. Check if containers are running with: sudo docker-compose ps"
echo "2. View logs with: sudo docker-compose logs"
echo "3. If issues persist, check individual service logs" 