#!/bin/bash

echo "🚨 FIXING NGINX DOMAIN ROUTING ISSUE"
echo "===================================="
echo ""
echo "Problem: Backend URL routing to frontend because nginx is configured for localhost"
echo "Solution: Update .env file with production domains"
echo ""

# Set connection details
EC2_USER="ec2-user"
EC2_HOST="ec2-54-237-212-127.compute-1.amazonaws.com"
KEY_FILE="../../../car-rental-key.pem"

echo "🔧 UPDATING NGINX DOMAIN CONFIGURATION ON EC2..."
echo "================================================"

# Create the fix commands
COMMANDS=$(cat << 'EOF'
echo "📍 Current location: $(pwd)"
echo ""

echo "🔍 CHECKING CURRENT DOMAIN CONFIGURATION:"
echo "========================================="
cd /home/ec2-user/sms-seller-connect-infrastructure
grep "SMS.*DOMAIN" config/.env
echo ""

echo "🔧 UPDATING DOMAIN CONFIGURATION:"
echo "================================="
# Update the domains in .env file
sed -i 's/SMS_API_DOMAIN=api.localhost/SMS_API_DOMAIN=api.sms.typerelations.com/' config/.env
sed -i 's/SMS_FRONTEND_DOMAIN=localhost/SMS_FRONTEND_DOMAIN=sms.typerelations.com/' config/.env

echo "✅ NEW DOMAIN CONFIGURATION:"
echo "============================"
grep "SMS.*DOMAIN" config/.env
echo ""

echo "🔄 RESTARTING NGINX TO APPLY CHANGES:"
echo "====================================="
docker-compose restart nginx_proxy

echo ""
echo "⏳ WAITING FOR NGINX TO RESTART..."
sleep 5

echo ""
echo "🔍 CHECKING NGINX STATUS:"
echo "========================"
docker-compose ps nginx_proxy

echo ""
echo "✅ DOMAIN ROUTING FIX COMPLETE!"
echo "=============================="
echo "Backend should now route correctly to port 8900"
echo "Frontend should route correctly to port 8082"
echo ""
echo "🧪 TEST COMMANDS:"
echo "=================="
echo "Backend: curl -H 'Host: api.sms.typerelations.com' http://localhost/health"
echo "Frontend: curl -H 'Host: sms.typerelations.com' http://localhost/"
EOF
)

echo "🚀 EXECUTING FIX ON EC2 INSTANCE..."
echo "==================================="
ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" "$COMMANDS"

echo ""
echo "🎉 NGINX DOMAIN ROUTING FIX APPLIED!"
echo "===================================="
echo ""
echo "✅ What was fixed:"
echo "- Changed SMS_API_DOMAIN from 'api.localhost' to 'api.sms.typerelations.com'"
echo "- Changed SMS_FRONTEND_DOMAIN from 'localhost' to 'sms.typerelations.com'"
echo "- Restarted nginx_proxy container to apply changes"
echo ""
echo "🌐 Your backend should now be accessible at:"
echo "- Via ALB: http://sms-seller-connect-prod-alb-1244462026.us-east-1.elb.amazonaws.com"
echo "- Via domain (when DNS ready): https://api.sms.typerelations.com"
echo ""
echo "🧪 To test the fix:"
echo "curl -H 'Host: api.sms.typerelations.com' http://sms-seller-connect-prod-alb-1244462026.us-east-1.elb.amazonaws.com/health" 