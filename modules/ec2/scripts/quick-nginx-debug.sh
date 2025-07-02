#!/bin/bash

# Quick Nginx Debug Script
echo "�� Quick Nginx Troubleshooting"
echo "=============================="

SSH_KEY="../car-rental-key.pem"
SSH_USER="ec2-user"
SSH_HOST="98.81.70.146"
REMOTE_DIR="/app/sms-seller-connect"

echo ""
echo "1️⃣ Checking nginx config line 28..."
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "cd $REMOTE_DIR && sed -n '28p' nginx.conf"

echo ""
echo "2️⃣ Looking for 'must-revalidate' issues..."
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "cd $REMOTE_DIR && grep -n 'must-revalidate' nginx.conf"

echo ""
echo "3️⃣ Checking recent nginx logs..."
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "cd $REMOTE_DIR && sudo docker-compose logs --tail 10 nginx"

echo ""
echo "4️⃣ Container status..."
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "cd $REMOTE_DIR && sudo docker-compose ps nginx"

