#!/bin/bash

# Frontend-Backend Connectivity Diagnosis Script
# Run this directly on the EC2 instance via SSH

echo "=== FRONTEND-BACKEND CONNECTIVITY DIAGNOSIS ==="
echo "==============================================="
echo ""

cd /app/sms-seller-connect 2>/dev/null || {
    echo "ERROR: Cannot access /app/sms-seller-connect directory"
    exit 1
}

# 1. Check frontend environment variables
echo "1. Frontend Environment Variables:"
echo "=================================="
echo "Checking frontend container API configuration:"
sudo docker exec sms_frontend printenv | grep -E "(API|BACKEND|VITE|REACT)" | sort
echo ""

# 2. Test backend accessibility from host
echo "2. Backend Accessibility from Host:"
echo "==================================="
echo "Testing backend health endpoint from host:"
curl -v http://localhost:8900/health 2>&1 | head -20
echo ""

# 3. Test backend accessibility from frontend container
echo "3. Backend Accessibility from Frontend Container:"
echo "================================================="
echo "Testing if frontend container can reach backend via container name:"
sudo docker exec sms_frontend curl -v http://sms_backend:8900/health 2>&1 | head -15 || echo "FAILED - cannot reach backend via container name"
echo ""

echo "Testing if frontend container can reach backend via localhost:"
sudo docker exec sms_frontend curl -v http://localhost:8900/health 2>&1 | head -15 || echo "FAILED - cannot reach backend via localhost"
echo ""

# 4. Check frontend application console errors
echo "4. Frontend Application Analysis:"
echo "================================="
echo "Checking frontend container logs for API errors:"
sudo docker logs --tail 50 sms_frontend | grep -i -E "(error|failed|refused|timeout|api)" || echo "No obvious API errors in frontend logs"
echo ""

# 5. Test actual API endpoints frontend would use
echo "5. Testing Specific API Endpoints:"
echo "=================================="

# Common endpoints the frontend might call
API_ENDPOINTS=(
    "/health"
    "/api/health" 
    "/api/leads"
    "/api/messages"
    "/api/auth/status"
    "/docs"
)

echo "Testing endpoints from host (localhost:8900):"
for endpoint in "${API_ENDPOINTS[@]}"; do
    echo -n "  $endpoint: "
    curl -f -s --connect-timeout 5 "http://localhost:8900$endpoint" >/dev/null && echo "SUCCESS" || echo "FAILED"
done
echo ""

echo "Testing endpoints from frontend container (sms_backend:8900):"
for endpoint in "${API_ENDPOINTS[@]}"; do
    echo -n "  $endpoint: "
    sudo docker exec sms_frontend curl -f -s --connect-timeout 5 "http://sms_backend:8900$endpoint" >/dev/null 2>&1 && echo "SUCCESS" || echo "FAILED"
done
echo ""

# 6. Check CORS headers
echo "6. CORS Configuration Check:"
echo "============================"
echo "Testing CORS headers from backend:"
curl -H "Origin: https://sms.typerelations.com" -H "Access-Control-Request-Method: GET" -H "Access-Control-Request-Headers: X-Requested-With" -X OPTIONS http://localhost:8900/health -v 2>&1 | grep -i "access-control" || echo "No CORS headers found"
echo ""

# 7. Check nginx proxy configuration for API routes
echo "7. Nginx API Routing Check:"
echo "==========================="
echo "Testing API route through nginx:"
curl -f -s --connect-timeout 5 http://localhost:80/api/health >/dev/null && echo "SUCCESS - nginx routes /api correctly" || echo "FAILED - nginx API routing issue"

echo "Testing backend route through nginx:"
curl -f -s --connect-timeout 5 http://localhost:80/health >/dev/null && echo "SUCCESS - nginx routes /health correctly" || echo "FAILED - nginx health routing issue"
echo ""

# 8. Check what the frontend is actually trying to connect to
echo "8. Frontend Runtime Configuration:"
echo "=================================="
echo "Checking what API URL the frontend is actually using:"

# Try to get the frontend's runtime configuration
echo "Attempting to extract API configuration from frontend:"
FRONTEND_CONFIG=$(curl -s http://localhost:8082 2>/dev/null | grep -o 'VITE_API_URL[^"]*' | head -1)
if [ -n "$FRONTEND_CONFIG" ]; then
    echo "Found frontend API config: $FRONTEND_CONFIG"
else
    echo "Could not extract API configuration from frontend"
fi

# Check if frontend has any JavaScript console errors related to API
echo ""
echo "Checking frontend source for API endpoints:"
curl -s http://localhost:8082 2>/dev/null | grep -o 'api[^"]*' | head -5 || echo "No API references found in frontend source"
echo ""

# 9. Network connectivity test
echo "9. Network Connectivity Test:"
echo "============================="
echo "Docker network information:"
sudo docker network ls
echo ""

echo "Frontend container network details:"
sudo docker inspect sms_frontend --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "Cannot get frontend IP"

echo "Backend container network details:"
sudo docker inspect sms_backend --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "Cannot get backend IP"
echo ""

# 10. Live API call test from frontend
echo "10. Live Frontend-to-Backend Test:"
echo "=================================="
echo "Testing live API call from frontend container:"

# Create a test script inside the frontend container
TEST_SCRIPT='
echo "Testing API endpoints from frontend container:";
echo "1. Health endpoint:";
curl -s -w "Status: %{http_code}\n" http://sms_backend:8900/health || echo "Failed";
echo "";
echo "2. API health endpoint:";
curl -s -w "Status: %{http_code}\n" http://sms_backend:8900/api/health || echo "Failed";
echo "";
echo "3. Docs endpoint:";
curl -s -w "Status: %{http_code}\n" http://sms_backend:8900/docs | head -1 || echo "Failed";
'

sudo docker exec sms_frontend sh -c "$TEST_SCRIPT"
echo ""

# 11. Diagnosis summary and recommendations
echo "11. DIAGNOSIS SUMMARY & RECOMMENDATIONS:"
echo "========================================"

BACKEND_HEALTH=$(curl -f -s --connect-timeout 5 http://localhost:8900/health >/dev/null && echo "OK" || echo "FAILED")
FRONTEND_TO_BACKEND=$(sudo docker exec sms_frontend curl -f -s --connect-timeout 5 http://sms_backend:8900/health >/dev/null 2>&1 && echo "OK" || echo "FAILED")
NGINX_API_ROUTING=$(curl -f -s --connect-timeout 5 http://localhost:80/api/health >/dev/null && echo "OK" || echo "FAILED")

echo "Backend Health: $BACKEND_HEALTH"
echo "Frontend->Backend: $FRONTEND_TO_BACKEND"  
echo "Nginx API Routing: $NGINX_API_ROUTING"
echo ""

if [ "$BACKEND_HEALTH" = "FAILED" ]; then
    echo "ISSUE: Backend is not responding to health checks"
    echo "FIX: sudo docker-compose restart sms_backend"
    echo ""
elif [ "$FRONTEND_TO_BACKEND" = "FAILED" ]; then
    echo "ISSUE: Frontend container cannot reach backend container"
    echo "POSSIBLE CAUSES:"
    echo "1. Docker network connectivity issue"
    echo "2. Backend container not responding on internal network"
    echo "3. Wrong environment variables in frontend container"
    echo ""
    echo "FIXES TO TRY:"
    echo "1. Restart both containers: sudo docker-compose restart sms_frontend sms_backend"
    echo "2. Check frontend env vars: sudo docker exec sms_frontend printenv | grep API"
    echo "3. Recreate containers: sudo docker-compose down && sudo docker-compose up -d"
    echo ""
elif [ "$NGINX_API_ROUTING" = "FAILED" ]; then
    echo "ISSUE: Nginx is not properly routing API requests"
    echo "FIX: sudo docker-compose restart nginx"
    echo ""
else
    echo "ISSUE: All services appear to be working, but frontend still reports backend down"
    echo "POSSIBLE CAUSES:"
    echo "1. Frontend is using wrong API URL (check browser console)"
    echo "2. CORS issues (check browser console for CORS errors)"
    echo "3. Frontend caching old configuration"
    echo "4. SSL/TLS issues if using HTTPS"
    echo ""
    echo "FIXES TO TRY:"
    echo "1. Clear browser cache and reload frontend"
    echo "2. Check browser console for specific error messages"
    echo "3. Restart frontend container: sudo docker-compose restart sms_frontend"
    echo "4. Check if frontend is using correct API URL in browser developer tools"
fi

echo "=== DIAGNOSIS COMPLETED ===" 