#!/bin/bash

echo "🔧 FIXING NGINX HEALTH ON EC2 INSTANCE"
echo "======================================"
echo ""

# Instance ID
INSTANCE_ID="i-0072d9109457c2539"

echo "📋 Sending diagnostic and fix commands to EC2 instance..."
echo ""

# Send simple command to restart nginx and check status
COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters commands='["cd /app/sms-seller-connect && sudo docker restart nginx_proxy && sleep 10 && sudo docker ps && curl -I localhost:80"]' \
    --comment "Fix Nginx Health" \
    --query 'Command.CommandId' \
    --output text)

if [ -n "$COMMAND_ID" ]; then
    echo "✅ Command sent successfully: $COMMAND_ID"
    echo "⏳ Waiting for execution..."
    
    # Wait for command to complete
    aws ssm wait command-executed \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID"
    
    echo "📊 Command output:"
    aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --query 'StandardOutputContent' \
        --output text
        
    echo ""
    echo "🔍 Command status:"
    aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --query 'Status' \
        --output text
else
    echo "❌ Failed to send command"
fi

echo ""
echo "🎯 Next steps:"
echo "1. Check if nginx is now healthy"
echo "2. Test the application: https://sms.typerelations.com"
echo "3. Verify HTTPS API calls work without mixed content errors" 