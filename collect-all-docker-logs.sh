#!/bin/bash

echo "=== Collecting all Docker logs from EC2 instance ==="
echo "Saving to: modules/ec2/ec2-debug-output/"
echo ""

# 1. Complete Docker Compose logs
echo "1/8 Collecting complete Docker logs..."
ssh -i car-rental-key.pem ec2-user@98.81.70.146 'cd /app/sms-seller-connect && sudo docker-compose logs --tail 2000' > modules/ec2/ec2-debug-output/complete-docker-logs-$(date +%Y%m%d_%H%M%S).log

# 2. Backend service logs
echo "2/8 Collecting backend logs..."
ssh -i car-rental-key.pem ec2-user@98.81.70.146 'cd /app/sms-seller-connect && sudo docker-compose logs sms_backend' > modules/ec2/ec2-debug-output/backend-logs.log

# 3. Frontend service logs
echo "3/8 Collecting frontend logs..."
ssh -i car-rental-key.pem ec2-user@98.81.70.146 'cd /app/sms-seller-connect && sudo docker-compose logs sms_frontend' > modules/ec2/ec2-debug-output/frontend-logs.log

# 4. Nginx proxy logs
echo "4/8 Collecting nginx logs..."
ssh -i car-rental-key.pem ec2-user@98.81.70.146 'cd /app/sms-seller-connect && sudo docker-compose logs nginx' > modules/ec2/ec2-debug-output/nginx-logs.log

# 5. Health check service logs
echo "5/8 Collecting health check logs..."
ssh -i car-rental-key.pem ec2-user@98.81.70.146 'cd /app/sms-seller-connect && sudo docker-compose logs health_check' > modules/ec2/ec2-debug-output/health-check-logs.log

# 6. Services status
echo "6/8 Collecting services status..."
ssh -i car-rental-key.pem ec2-user@98.81.70.146 'cd /app/sms-seller-connect && sudo docker-compose ps' > modules/ec2/ec2-debug-output/services-status.log

# 7. Recent logs (last 4 hours)
echo "7/8 Collecting recent logs (4h)..."
ssh -i car-rental-key.pem ec2-user@98.81.70.146 'cd /app/sms-seller-connect && sudo docker-compose logs --since 4h' > modules/ec2/ec2-debug-output/recent-4h-logs.log

# 8. Docker system info
echo "8/8 Collecting Docker system info..."
ssh -i car-rental-key.pem ec2-user@98.81.70.146 'cd /app/sms-seller-connect && sudo docker system df && echo "=== CONTAINER STATS ===" && sudo docker stats --no-stream' > modules/ec2/ec2-debug-output/docker-system-info.log

echo ""
echo "✅ All logs collected in: modules/ec2/ec2-debug-output/"
echo ""
echo "Files created:"
ls -la modules/ec2/ec2-debug-output/*.log 2>/dev/null || echo "Log files will appear after running the commands"
