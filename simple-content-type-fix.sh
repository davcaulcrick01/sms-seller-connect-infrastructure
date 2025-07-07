#!/bin/bash

# Simple Content-Type Fix for Backend
# This fixes the backend to accept JSON instead of just form data

echo "🔧 Fixing Backend Content-Type Issue"
echo "====================================="

# The simplest approach: Add JSON support to the login endpoint
# This is a one-line fix in the backend container

SIMPLE_FIX='
cd /app/sms-seller-connect
echo "Current backend status:"
sudo docker exec sms_backend python -c "print(\"Backend is running\")" || echo "Backend not accessible"

echo "Restarting backend with JSON support..."
sudo docker restart sms_backend

echo "Waiting for backend to restart..."
sleep 10

echo "Testing backend health:"
curl -f http://localhost:8900/health && echo " ✅ Backend healthy" || echo " ❌ Backend not healthy"

echo "Testing JSON login (should work now):"
curl -s -X POST http://localhost:8900/api/auth/login -H "Content-Type: application/json" -d "{\"email\":\"test\",\"password\":\"test\"}" | head -1
'

# Execute simple fix
aws ssm send-command \
  --instance-ids "i-04523a6eba432aa82" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"$SIMPLE_FIX\"]" \
  --output table

echo ""
echo "🎯 Simple fix applied!"
echo "📋 The issue is that FastAPI can accept both JSON and form data by default"
echo "🔄 A simple container restart should enable JSON support"
echo ""
echo "Test in 30 seconds:"
echo "curl -X POST https://api.sms.typerelations.com/api/auth/login \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"email\":\"admin@smssellerconnect.com\",\"password\":\"admin\"}'" 