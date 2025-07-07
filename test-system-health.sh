#!/bin/bash

# Comprehensive system health test script
# Run this on the EC2 instance to verify all services are working

echo "🏥 SMS Seller Connect - System Health Check"
echo "=========================================="

# Phase 1: Container Status
echo "📋 Phase 1: Container Status Check"
echo "Container Status:"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo -e "\nContainer Health Status:"
sudo docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(healthy|unhealthy|starting)"

# Phase 2: Health Endpoints
echo -e "\n🔍 Phase 2: Health Endpoints Test"

echo "Backend Health:"
curl -s http://localhost:8900/health || echo "❌ Backend health check failed"

echo -e "\nHealth Check Service:"
curl -s http://localhost:8888/status || echo "❌ Health check service failed"

echo -e "\nNginx ALB Health:"
curl -s http://localhost/alb-health || echo "❌ ALB health check failed"

# Phase 3: API Endpoints (CORS & Redirect Test)
echo -e "\n🌐 Phase 3: API Endpoints (CORS & Redirect Test)"

echo "Testing /api/leads (should not redirect):"
RESPONSE=$(curl -s -w "HTTP_CODE:%{http_code}" -H "Host: api.sms.typerelations.com" http://localhost/api/leads)
HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ /api/leads returns 200 (no redirect)"
elif [ "$HTTP_CODE" = "307" ]; then
    echo "❌ /api/leads returns 307 (still redirecting)"
else
    echo "⚠️  /api/leads returns $HTTP_CODE"
fi

echo -e "\nTesting CORS headers:"
CORS_HEADERS=$(curl -s -H "Host: api.sms.typerelations.com" -H "Origin: https://sms.typerelations.com" -I http://localhost/api/leads/ | grep -i "access-control")
echo "$CORS_HEADERS"

CREDENTIALS_COUNT=$(echo "$CORS_HEADERS" | grep -i "access-control-allow-credentials" | wc -l)
if [ "$CREDENTIALS_COUNT" -eq 1 ]; then
    echo "✅ Single CORS credentials header (no duplication)"
else
    echo "❌ Multiple CORS credentials headers detected"
fi

# Phase 4: Frontend Test
echo -e "\n🖥️  Phase 4: Frontend Test"

echo "Frontend Loading:"
FRONTEND_RESPONSE=$(curl -s -H "Host: sms.typerelations.com" http://localhost/ | grep -i title)
if [ -n "$FRONTEND_RESPONSE" ]; then
    echo "✅ Frontend loads successfully"
    echo "Title: $FRONTEND_RESPONSE"
else
    echo "❌ Frontend failed to load"
fi

# Phase 5: Database Connectivity (via API)
echo -e "\n🗄️  Phase 5: Database Connectivity Test"

echo "Testing leads count API:"
LEADS_COUNT=$(curl -s -H "Host: api.sms.typerelations.com" http://localhost/api/leads/count)
if echo "$LEADS_COUNT" | grep -q "count"; then
    echo "✅ Database connectivity working"
    echo "Response: $LEADS_COUNT"
else
    echo "❌ Database connectivity issue"
fi

# Summary
echo -e "\n📊 System Health Summary"
echo "========================"

# Count successful tests
TESTS_PASSED=0
TOTAL_TESTS=6

# Check each component
sudo docker ps | grep -q "Up.*healthy.*nginx" && TESTS_PASSED=$((TESTS_PASSED + 1)) && echo "✅ Nginx: Running and healthy"
sudo docker ps | grep -q "Up.*healthy.*sms_backend" && TESTS_PASSED=$((TESTS_PASSED + 1)) && echo "✅ Backend: Running and healthy"
sudo docker ps | grep -q "Up.*healthy.*sms_frontend" && TESTS_PASSED=$((TESTS_PASSED + 1)) && echo "✅ Frontend: Running and healthy"
sudo docker ps | grep -q "Up.*healthy.*health_check" && TESTS_PASSED=$((TESTS_PASSED + 1)) && echo "✅ Health Check: Running and healthy"

[ "$HTTP_CODE" = "200" ] && TESTS_PASSED=$((TESTS_PASSED + 1)) && echo "✅ API: No redirects"
[ "$CREDENTIALS_COUNT" -eq 1 ] && TESTS_PASSED=$((TESTS_PASSED + 1)) && echo "✅ CORS: No header duplication"

echo -e "\nOverall Health: $TESTS_PASSED/$TOTAL_TESTS tests passed"

if [ "$TESTS_PASSED" -eq "$TOTAL_TESTS" ]; then
    echo "🎉 ALL SYSTEMS HEALTHY - READY FOR PRODUCTION!"
    exit 0
elif [ "$TESTS_PASSED" -ge 4 ]; then
    echo "⚠️  MOSTLY HEALTHY - Minor issues need attention"
    exit 1
else
    echo "❌ SYSTEM UNHEALTHY - Critical issues need resolution"
    exit 2
fi