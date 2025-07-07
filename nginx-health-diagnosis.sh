#!/bin/bash

# Nginx Health Diagnosis Script
# Run this directly on the EC2 instance via SSH

echo "=== NGINX HEALTH DIAGNOSIS ==="
echo "=============================="
echo ""

# 1. Check container status
echo "1. Container Status:"
echo "==================="
sudo docker ps -a
echo ""

# 2. Check nginx logs
echo "2. Nginx Container Logs (last 30 lines):"
echo "========================================="
sudo docker logs --tail 30 nginx_proxy
echo ""

# 3. Check health check service logs 
echo "3. Health Check Service Logs (last 30 lines):"
echo "=============================================="
sudo docker logs --tail 30 health_check_service
echo ""

# 4. Test nginx configuration
echo "4. Nginx Configuration Test:"
echo "==========================="
sudo docker exec nginx_proxy nginx -t 2>&1 || echo "Cannot test nginx config"
echo ""

# 5. Check what's listening on ports
echo "5. Port Status Check:"
echo "===================="
echo "Port 80 (nginx):"
sudo netstat -tlnp | grep :80 || echo "Nothing listening on port 80"
echo ""
echo "Port 8888 (health check service):"
sudo netstat -tlnp | grep :8888 || echo "Nothing listening on port 8888"
echo ""
echo "Port 8900 (backend):"
sudo netstat -tlnp | grep :8900 || echo "Nothing listening on port 8900"
echo ""

# 6. Test endpoints manually
echo "6. Manual Endpoint Tests:"
echo "========================="
echo "Testing backend health:"
curl -f -s --connect-timeout 5 http://localhost:8900/health && echo " SUCCESS" || echo " FAILED"

echo "Testing health check service:"
curl -f -s --connect-timeout 5 http://localhost:8888/status && echo " SUCCESS" || echo " FAILED"

echo "Testing nginx ALB health endpoint:"
curl -f -s --connect-timeout 5 http://localhost:80/alb-health && echo " SUCCESS" || echo " FAILED"

echo "Testing nginx root:"
curl -f -s --connect-timeout 5 http://localhost:80/ && echo " SUCCESS" || echo " FAILED"
echo ""

# 7. Check nginx configuration content
echo "7. Nginx Configuration Content:"
echo "==============================="
sudo docker exec nginx_proxy cat /etc/nginx/nginx.conf | head -50
echo ""

# 8. Check health check service files
echo "8. Health Check Service Files:"
echo "============================="
echo "Checking if health check script exists:"
sudo docker exec health_check_service ls -la /app/ 2>/dev/null || echo "Cannot access health check service files"
echo ""

# 9. Backend container health check
echo "9. Backend Container Health:"
echo "==========================="
echo "Backend container inspection:"
sudo docker inspect sms_backend --format '{{.State.Status}}: {{.State.Health.Status}}' 2>/dev/null || echo "Cannot inspect backend"
echo ""

# 10. Frontend container status
echo "10. Frontend Container Status:"
echo "============================="
echo "Frontend container inspection:"
sudo docker inspect sms_frontend --format '{{.State.Status}}: {{.State.Health.Status}}' 2>/dev/null || echo "Cannot inspect frontend"
echo ""

# 11. Try to restart failing services
echo "11. Service Restart Recommendations:"
echo "==================================="
echo "Based on the above diagnosis:"
echo ""

# Check which services are failing and provide specific restart commands
if ! sudo docker logs health_check_service 2>/dev/null | tail -5 | grep -q "healthy"; then
    echo "Health Check Service appears to be failing."
    echo "Restart command: sudo docker-compose restart health_check"
    echo ""
fi

if ! curl -f -s --connect-timeout 5 http://localhost:8900/health >/dev/null; then
    echo "Backend appears to be unhealthy."
    echo "Restart command: sudo docker-compose restart sms_backend"
    echo ""
fi

if ! curl -f -s --connect-timeout 5 http://localhost:80/alb-health >/dev/null; then
    echo "Nginx ALB health endpoint is failing."
    echo "Restart command: sudo docker-compose restart nginx"
    echo ""
fi

echo "To restart all services:"
echo "sudo docker-compose restart"
echo ""

echo "=== DIAGNOSIS COMPLETED ===" 