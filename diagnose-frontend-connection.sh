#!/bin/bash

# Frontend Connection Diagnosis Script
# This script diagnoses why the frontend is getting net::ERR_CONNECTION_REFUSED

set -e

echo "🔍 FRONTEND CONNECTION DIAGNOSIS"
echo "================================="
echo ""

# Get EC2 instance details
echo "📡 Getting EC2 instance details..."
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=sms-seller-connect-prod-ec2" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

if [ "$INSTANCE_ID" = "None" ] || [ "$INSTANCE_ID" = "null" ]; then
  echo "❌ No running EC2 instance found"
  exit 1
fi

INSTANCE_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "✅ Found EC2 instance:"
echo "  Instance ID: $INSTANCE_ID"
echo "  Public IP: $INSTANCE_IP"

# Create comprehensive diagnostic command
DIAGNOSTIC_COMMAND=$(cat << 'EOF'
#!/bin/bash

echo "🔍 COMPREHENSIVE FRONTEND CONNECTION DIAGNOSIS"
echo "=============================================="
echo "Timestamp: $(date)"
echo ""

# 1. Check all container status
echo "📦 CONTAINER STATUS CHECK:"
echo "========================="
echo ""

cd /app/sms-seller-connect 2>/dev/null || {
    echo "❌ Application directory not found: /app/sms-seller-connect"
    echo "Available directories in /app:"
    ls -la /app/ 2>/dev/null || echo "Cannot access /app"
    exit 1
}

echo "✅ In application directory: $(pwd)"
echo ""

echo "Docker Compose service status:"
sudo docker-compose ps || echo "❌ Cannot get docker-compose status"

echo ""
echo "All Docker containers:"
sudo docker ps -a || echo "❌ Cannot get docker status"

echo ""
echo "🌐 NETWORK CONNECTIVITY CHECK:"
echo "==============================="

# 2. Check if backend is accessible from host
echo "Testing backend from host:"
echo "- Backend health check:"
curl -f -s --connect-timeout 5 http://localhost:8900/health && echo " ✅ Backend accessible from host" || echo " ❌ Backend not accessible from host"

echo "- Backend API docs:"
curl -f -s --connect-timeout 5 http://localhost:8900/docs >/dev/null && echo " ✅ Backend docs accessible" || echo " ❌ Backend docs not accessible"

# 3. Check if frontend container is running and accessible
echo ""
echo "Testing frontend from host:"
echo "- Frontend health check:"
curl -f -s --connect-timeout 5 http://localhost:8082 >/dev/null && echo " ✅ Frontend accessible from host" || echo " ❌ Frontend not accessible from host"

# 4. Check internal container networking
echo ""
echo "Testing internal container networking:"

# Test if frontend can reach backend internally
if sudo docker exec sms_frontend curl -f -s --connect-timeout 5 http://sms_backend:8900/health >/dev/null 2>&1; then
    echo " ✅ Frontend container can reach backend container"
else
    echo " ❌ Frontend container CANNOT reach backend container"
fi

# Test if frontend can reach backend via localhost
if sudo docker exec sms_frontend curl -f -s --connect-timeout 5 http://localhost:8900/health >/dev/null 2>&1; then
    echo " ✅ Frontend container can reach backend via localhost"
else
    echo " ❌ Frontend container cannot reach backend via localhost"
fi

# 5. Check ALB health endpoint
echo ""
echo "Testing ALB health endpoint:"
curl -f -s --connect-timeout 5 http://localhost:80/alb-health && echo " ✅ ALB health endpoint working" || echo " ❌ ALB health endpoint not working"

# 6. Check nginx status and configuration
echo ""
echo "🌐 NGINX STATUS CHECK:"
echo "======================"
echo ""

echo "Nginx container logs (last 20 lines):"
sudo docker logs --tail 20 nginx_proxy 2>/dev/null || echo "Cannot get nginx logs"

echo ""
echo "Nginx configuration test:"
sudo docker exec nginx_proxy nginx -t 2>/dev/null || echo "Cannot test nginx configuration"

# 7. Check frontend container logs
echo ""
echo "🎨 FRONTEND CONTAINER CHECK:"
echo "============================"
echo ""

echo "Frontend container status:"
sudo docker inspect sms_frontend --format '{{.State.Status}}: {{.State.Health.Status}}' 2>/dev/null || echo "Cannot get frontend container status"

echo ""
echo "Frontend container logs (last 30 lines):"
sudo docker logs --tail 30 sms_frontend 2>/dev/null || echo "Cannot get frontend logs"

# 8. Check environment variables in frontend container
echo ""
echo "Frontend container environment variables (API-related):"
sudo docker exec sms_frontend printenv | grep -E "(API|BACKEND|VITE)" 2>/dev/null || echo "Cannot get frontend environment variables"

# 9. Test actual frontend application
echo ""
echo "🔍 FRONTEND APPLICATION CHECK:"
echo "==============================="

# Check if frontend is serving content
echo "Frontend root endpoint test:"
FRONTEND_RESPONSE=$(curl -s -w "%{http_code}" --connect-timeout 5 http://localhost:8082 -o /dev/null 2>/dev/null || echo "000")
echo "Frontend HTTP response code: $FRONTEND_RESPONSE"

if [ "$FRONTEND_RESPONSE" = "200" ]; then
    echo " ✅ Frontend is serving content"
    
    # Check if frontend is making API calls
    echo ""
    echo "Checking frontend's API configuration:"
    curl -s --connect-timeout 5 http://localhost:8082 | grep -o 'VITE_API_URL[^"]*' | head -5 || echo "Cannot find API configuration in frontend"
    
else
    echo " ❌ Frontend is not serving content properly"
fi

# 10. Check domain resolution
echo ""
echo "🌍 DOMAIN RESOLUTION CHECK:"
echo "============================"

echo "DNS resolution test:"
nslookup sms.typerelations.com || echo "Cannot resolve frontend domain"
nslookup api.sms.typerelations.com || echo "Cannot resolve API domain"

# 11. Check external access
echo ""
echo "🌐 EXTERNAL ACCESS CHECK:"
echo "========================="

EXTERNAL_IP=$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "unknown")
echo "Instance external IP: $EXTERNAL_IP"

if [ "$EXTERNAL_IP" != "unknown" ]; then
    echo "Testing external access to frontend:"
    curl -f -s --connect-timeout 10 "http://$EXTERNAL_IP:8082" >/dev/null && echo " ✅ Frontend accessible externally" || echo " ❌ Frontend not accessible externally"
    
    echo "Testing external access to backend:"
    curl -f -s --connect-timeout 10 "http://$EXTERNAL_IP:8900/health" >/dev/null && echo " ✅ Backend accessible externally" || echo " ❌ Backend not accessible externally"
fi

# 12. Final diagnosis summary
echo ""
echo "📋 DIAGNOSIS SUMMARY:"
echo "====================="

BACKEND_STATUS=$(curl -f -s --connect-timeout 5 http://localhost:8900/health >/dev/null && echo "WORKING" || echo "FAILED")
FRONTEND_STATUS=$(curl -f -s --connect-timeout 5 http://localhost:8082 >/dev/null && echo "WORKING" || echo "FAILED")
ALB_STATUS=$(curl -f -s --connect-timeout 5 http://localhost:80/alb-health >/dev/null && echo "WORKING" || echo "FAILED")

echo "Backend API: $BACKEND_STATUS"
echo "Frontend App: $FRONTEND_STATUS"  
echo "ALB Health: $ALB_STATUS"

if [ "$BACKEND_STATUS" = "WORKING" ] && [ "$FRONTEND_STATUS" = "FAILED" ]; then
    echo ""
    echo "🔍 LIKELY ISSUE: Frontend container problem"
    echo "Recommended actions:"
    echo "1. Check frontend container logs: sudo docker logs sms_frontend"
    echo "2. Restart frontend container: sudo docker-compose restart sms_frontend"
    echo "3. Verify frontend environment variables"
    echo "4. Check if frontend is built correctly"
    
elif [ "$BACKEND_STATUS" = "WORKING" ] && [ "$FRONTEND_STATUS" = "WORKING" ] && [ "$ALB_STATUS" = "FAILED" ]; then
    echo ""
    echo "🔍 LIKELY ISSUE: Nginx/ALB configuration problem"
    echo "Recommended actions:"
    echo "1. Check nginx configuration: sudo docker exec nginx_proxy nginx -t"
    echo "2. Restart nginx: sudo docker-compose restart nginx"
    echo "3. Check ALB target group health"
    
elif [ "$BACKEND_STATUS" = "FAILED" ]; then
    echo ""
    echo "🔍 LIKELY ISSUE: Backend container problem (even though logs looked good)"
    echo "Recommended actions:"
    echo "1. Check if backend container restarted: sudo docker ps"
    echo "2. Check backend logs: sudo docker logs sms_backend"
    echo "3. Verify backend environment variables"
    
else
    echo ""
    echo "🔍 ISSUE: Multiple components failing"
    echo "Recommended actions:"
    echo "1. Check docker-compose status: sudo docker-compose ps"
    echo "2. Restart all services: sudo docker-compose restart"
    echo "3. Check system resources: df -h && free -h"
fi

echo ""
echo "🏁 Diagnosis completed!"
EOF
)

echo ""
echo "📡 Executing comprehensive diagnosis via SSM..."

aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"$DIAGNOSTIC_COMMAND\"]" \
  --output text \
  --query 'Command.CommandId' > /tmp/ssm-diagnosis-id.txt

COMMAND_ID=$(cat /tmp/ssm-diagnosis-id.txt)
echo "✅ SSM Command sent with ID: $COMMAND_ID"

echo ""
echo "⏳ Waiting for diagnosis completion (this may take 1-2 minutes)..."

# Wait for command completion
MAX_WAIT=180  # 3 minutes
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS=$(aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --query 'Status' \
        --output text 2>/dev/null || echo "InProgress")
    
    case $STATUS in
        "Success")
            echo ""
            echo "✅ Diagnosis completed successfully!"
            break
            ;;
        "Failed")
            echo ""
            echo "❌ Diagnosis failed!"
            break
            ;;
        "InProgress")
            echo -n "."
            sleep 5
            ELAPSED=$((ELAPSED + 5))
            ;;
        *)
            echo -n "?"
            sleep 5
            ELAPSED=$((ELAPSED + 5))
            ;;
    esac
done

echo ""
echo "📋 DIAGNOSIS RESULTS:"
echo "===================="

aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query 'StandardOutputContent' \
    --output text

if [ "$STATUS" = "Failed" ]; then
    echo ""
    echo "❌ Error output:"
    aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --query 'StandardErrorContent' \
        --output text
fi

echo ""
echo "🏁 Frontend diagnosis completed!"
echo ""
echo "💡 If the issue is identified, you can run targeted fixes:"
echo "   - Frontend restart: sudo docker-compose restart sms_frontend"
echo "   - Nginx restart: sudo docker-compose restart nginx"  
echo "   - Full restart: sudo docker-compose restart" 