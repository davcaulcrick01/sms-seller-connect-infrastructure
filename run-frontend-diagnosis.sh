#!/bin/bash

# Local script to SSH to EC2 and run frontend-backend connectivity diagnosis

set -e

echo "🔍 RUNNING FRONTEND-BACKEND DIAGNOSIS ON EC2"
echo "============================================="
echo ""

# Configuration
KEY_FILE="car-rental-key.pem"
EC2_HOST="ec2-user@ec2-3-234-140-236.compute-1.amazonaws.com"

# Check if key file exists
if [ ! -f "$KEY_FILE" ]; then
    echo "❌ Error: SSH key file '$KEY_FILE' not found in current directory"
    echo "Please ensure the key file is in: $(pwd)"
    exit 1
fi

# Check key file permissions
chmod 600 "$KEY_FILE"

echo "✅ Using SSH key: $KEY_FILE"
echo "✅ Connecting to: $EC2_HOST"
echo ""

# Create the diagnosis command to run on EC2
DIAGNOSIS_COMMANDS='
echo "📥 Downloading frontend-backend connectivity diagnosis script..."
aws s3 cp s3://sms-seller-connect-bucket/scripts/frontend-backend-connectivity.sh /tmp/ || {
    echo "❌ Failed to download diagnosis script from S3"
    echo "Checking if script exists locally..."
    if [ ! -f /tmp/frontend-backend-connectivity.sh ]; then
        echo "Creating diagnosis script locally..."
        cat > /tmp/frontend-backend-connectivity.sh << '\''EOF'\''
#!/bin/bash

echo "=== FRONTEND-BACKEND CONNECTIVITY DIAGNOSIS ==="
echo "==============================================="
echo ""

cd /app/sms-seller-connect 2>/dev/null || {
    echo "ERROR: Cannot access /app/sms-seller-connect directory"
    exit 1
}

echo "1. Container Status:"
echo "==================="
sudo docker ps -a
echo ""

echo "2. Frontend Environment Variables:"
echo "=================================="
echo "Checking frontend container API configuration:"
sudo docker exec sms_frontend printenv | grep -E "(API|BACKEND|VITE|REACT)" | sort
echo ""

echo "3. Backend Health Test:"
echo "======================"
echo "Testing backend from host:"
curl -f -s --connect-timeout 5 http://localhost:8900/health && echo "SUCCESS" || echo "FAILED"
echo ""

echo "4. Frontend to Backend Test:"
echo "============================"
echo "Testing frontend container to backend container:"
sudo docker exec sms_frontend curl -f -s --connect-timeout 5 http://sms_backend:8900/health >/dev/null 2>&1 && echo "SUCCESS" || echo "FAILED"
echo ""

echo "5. Nginx API Routing Test:"
echo "=========================="
echo "Testing API through nginx:"
curl -f -s --connect-timeout 5 http://localhost:80/api/health >/dev/null && echo "SUCCESS" || echo "FAILED"
echo ""

echo "6. Frontend Logs:"
echo "================="
echo "Recent frontend container logs:"
sudo docker logs --tail 20 sms_frontend
echo ""

echo "7. Backend Logs:"
echo "==============="
echo "Recent backend container logs:"
sudo docker logs --tail 20 sms_backend
echo ""

echo "8. Nginx Logs:"
echo "=============="
echo "Recent nginx logs:"
sudo docker logs --tail 20 nginx_proxy
echo ""

echo "=== QUICK FIX RECOMMENDATIONS ==="
echo "If frontend cannot reach backend:"
echo "1. sudo docker-compose restart sms_frontend sms_backend"
echo "2. sudo docker-compose restart nginx"
echo "3. sudo docker-compose down && sudo docker-compose up -d"
echo ""
echo "=== DIAGNOSIS COMPLETED ==="
EOF
    fi
}

chmod +x /tmp/frontend-backend-connectivity.sh

echo "🚀 Running frontend-backend connectivity diagnosis..."
echo "====================================================="
/tmp/frontend-backend-connectivity.sh
'

echo "📡 Executing diagnosis on EC2 instance..."
echo ""

# SSH to EC2 and run the diagnosis
ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no "$EC2_HOST" "$DIAGNOSIS_COMMANDS"

DIAGNOSIS_EXIT_CODE=$?

echo ""
echo "🏁 DIAGNOSIS COMPLETED"
echo "====================="

if [ $DIAGNOSIS_EXIT_CODE -eq 0 ]; then
    echo "✅ Diagnosis completed successfully"
    echo ""
    echo "💡 NEXT STEPS:"
    echo "Based on the diagnosis results above:"
    echo "1. If frontend can't reach backend - restart containers"
    echo "2. If nginx routing failed - restart nginx"  
    echo "3. If all tests passed - check browser console for frontend errors"
    echo ""
    echo "🔧 QUICK FIXES TO RUN:"
    echo "ssh -i \"$KEY_FILE\" $EC2_HOST \"cd /app/sms-seller-connect && sudo docker-compose restart\""
else
    echo "❌ Diagnosis failed with exit code: $DIAGNOSIS_EXIT_CODE"
    echo ""
    echo "🔧 TRY MANUAL CONNECTION:"
    echo "ssh -i \"$KEY_FILE\" $EC2_HOST"
    echo "Then run: aws s3 cp s3://sms-seller-connect-bucket/scripts/frontend-backend-connectivity.sh /tmp/"
fi 