#!/bin/bash

# Nginx Config Fix Script
echo "🔧 Nginx Configuration Fix"
echo "=========================="

SSH_KEY="../car-rental-key.pem"
SSH_USER="ec2-user"
SSH_HOST="98.81.70.146"
REMOTE_DIR="/app/sms-seller-connect"

echo ""
echo "1️⃣ Backing up current nginx.conf..."
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "cd $REMOTE_DIR && cp nginx.conf nginx.conf.backup"

echo ""
echo "2️⃣ Applying common fixes..."
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "cd $REMOTE_DIR && sed -i 's/must-revalidate/\"must-revalidate\"/g' nginx.conf"
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "cd $REMOTE_DIR && sed -i 's/Cache-Control \"no-cache, must-revalidate\";/Cache-Control \"no-cache, must-revalidate\" always;/g' nginx.conf"

echo ""
echo "3️⃣ Testing nginx configuration..."
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "cd $REMOTE_DIR && sudo docker run --rm -v \$(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro nginx:alpine nginx -t"

if [ $? -eq 0 ]; then
    echo ""
    echo "4️⃣ Configuration valid! Restarting nginx..."
    ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "cd $REMOTE_DIR && sudo docker-compose restart nginx"
    
    echo ""
    echo "5️⃣ Checking if nginx is now running..."
    sleep 5
    ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "cd $REMOTE_DIR && sudo docker-compose ps nginx"
    
    echo ""
    echo "6️⃣ Testing HTTP access..."
    ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "curl -I http://localhost 2>/dev/null | head -1"
else
    echo ""
    echo "❌ Configuration still invalid. Manual intervention needed."
    echo "Restoring backup..."
    ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "cd $REMOTE_DIR && cp nginx.conf.backup nginx.conf"
fi

