# Triggering deployment after manual EC2 deletion - Tue Jun 17 18:09:39 CDT 2025
# Force pipeline trigger after state lock fix - Tue Jun 17 18:11:50 CDT 2025

INSTANCE_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=sms-seller-connect-prod-ec2" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "Instance IP: $INSTANCE_IP"

# Create debug output directory
mkdir -p ec2-debug-output

# Run all debug commands via SSH and save outputs locally
ssh -i car-rental-key.pem ec2-user@$INSTANCE_IP "
echo '=== BOOTSTRAP LOG ===' && sudo cat /var/log/bootstrap.log 2>/dev/null || echo 'Bootstrap log not found'
echo -e '\n=== CLOUD-INIT LOG ===' && sudo cat /var/log/cloud-init.log 2>/dev/null || echo 'Cloud-init log not found'
echo -e '\n=== CLOUD-INIT OUTPUT LOG ===' && sudo cat /var/log/cloud-init-output.log 2>/dev/null || echo 'Cloud-init output log not found'
echo -e '\n=== USER DATA SCRIPT ===' && sudo cat /tmp/user_data.sh 2>/dev/null || echo 'User data script not found'
echo -e '\n=== DOCKER CONTAINERS ===' && sudo docker ps -a 2>/dev/null || echo 'Docker not running'
echo -e '\n=== DOCKER COMPOSE STATUS ===' && cd /app/sms-seller-connect && sudo docker-compose ps 2>/dev/null || echo 'Docker compose not found'
echo -e '\n=== ENV FILE ===' && cd /app/sms-seller-connect && sudo cat .env 2>/dev/null || echo 'Env file not found'
echo -e '\n=== DOCKER COMPOSE FILE ===' && cd /app/sms-seller-connect && sudo cat docker-compose.yml 2>/dev/null || echo 'Docker compose file not found'
echo -e '\n=== ENVIRONMENT VARIABLES ===' && sudo env | grep -E '(BACKEND_IMAGE|FRONTEND_IMAGE|SMS_API_DOMAIN|DB_HOST)' 2>/dev/null || echo 'No matching env vars found'
echo -e '\n=== DIRECTORY LISTING ===' && ls -la /app/sms-seller-connect/ 2>/dev/null || echo 'App directory not found'
echo -e '\n=== S3 DOWNLOAD LOGS ===' && sudo cat /var/log/messages | grep -i s3 2>/dev/null || echo 'No S3 logs found'
" > ec2-debug-output/all-debug-info.txt

# Also save individual files for easier reading
ssh -i car-rental-key.pem ec2-user@$INSTANCE_IP "sudo cat /var/log/bootstrap.log" > ec2-debug-output/bootstrap.log 2>/dev/null || echo "Bootstrap log not available"
ssh -i car-rental-key.pem ec2-user@$INSTANCE_IP "sudo cat /var/log/cloud-init-output.log" > ec2-debug-output/cloud-init-output.log 2>/dev/null || echo "Cloud-init output not available"
ssh -i car-rental-key.pem ec2-user@$INSTANCE_IP "cd /app/sms-seller-connect && sudo cat .env" > ec2-debug-output/env-file.txt 2>/dev/null || echo "Env file not available"
ssh -i car-rental-key.pem ec2-user@$INSTANCE_IP "cd /app/sms-seller-connect && sudo cat docker-compose.yml" > ec2-debug-output/docker-compose.yml 2>/dev/null || echo "Docker compose not available"

echo "Debug information saved to ec2-debug-output/ directory"
echo "Main file: ec2-debug-output/all-debug-info.txt"