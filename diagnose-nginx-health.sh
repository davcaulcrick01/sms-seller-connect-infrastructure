#!/bin/bash

echo "🔍 NGINX PROXY HEALTH DIAGNOSTIC"
echo "================================"
echo ""

# Function to execute commands on EC2 via SSM
execute_remote_command() {
    local description="$1"
    local commands="$2"
    
    echo "📋 $description"
    
    # Use the known instance ID
    INSTANCE_ID="i-0072d9109457c2539"
    
    COMMAND_ID=$(aws ssm send-command \
        --instance-ids "$INSTANCE_ID" \
        --document-name "AWS-RunShellScript" \
        --parameters "commands=$commands" \
        --comment "$description" \
        --query 'Command.CommandId' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        # Wait for command to complete
        aws ssm wait command-executed \
            --command-id "$COMMAND_ID" \
            --instance-id "$INSTANCE_ID" \
            --cli-read-timeout 120 2>/dev/null
        
        # Get output
        aws ssm get-command-invocation \
            --command-id "$COMMAND_ID" \
            --instance-id "$INSTANCE_ID" \
            --query 'StandardOutputContent' \
            --output text 2>/dev/null
    else
        echo "❌ Failed to execute remote command"
    fi
    echo ""
}

# Diagnostic commands
echo "🔍 Step 1: Check container status..."
execute_remote_command "Container Status Check" '[
    "#!/bin/bash",
    "cd /app/sms-seller-connect",
    "echo \"=== DOCKER CONTAINER STATUS ===\"",
    "sudo docker ps -a",
    "echo \"\"",
    "echo \"=== DOCKER COMPOSE STATUS ===\"", 
    "sudo docker-compose ps"
]'

echo "🔍 Step 2: Check nginx container logs..."
execute_remote_command "Nginx Container Logs" '[
    "#!/bin/bash",
    "cd /app/sms-seller-connect",
    "echo \"=== NGINX CONTAINER LOGS (last 50 lines) ===\"",
    "sudo docker-compose logs --tail=50 nginx_proxy",
    "echo \"\"",
    "echo \"=== NGINX ERROR LOGS ===\"",
    "sudo docker exec nginx_proxy cat /var/log/nginx/error.log 2>/dev/null || echo \"No error log found\""
]'

echo "🔍 Step 3: Check nginx configuration..."
execute_remote_command "Nginx Configuration Check" '[
    "#!/bin/bash",
    "cd /app/sms-seller-connect",
    "echo \"=== NGINX CONFIGURATION ===\"",
    "sudo docker exec nginx_proxy cat /etc/nginx/nginx.conf 2>/dev/null || echo \"Cannot access nginx.conf\"",
    "echo \"\"",
    "echo \"=== NGINX SITES CONFIGURATION ===\"",
    "sudo docker exec nginx_proxy ls -la /etc/nginx/conf.d/ 2>/dev/null || echo \"No conf.d directory\"",
    "sudo docker exec nginx_proxy cat /etc/nginx/conf.d/default.conf 2>/dev/null || echo \"No default.conf found\""
]'

echo "🔍 Step 4: Test nginx health endpoint..."
execute_remote_command "Nginx Health Endpoint Test" '[
    "#!/bin/bash",
    "cd /app/sms-seller-connect",
    "echo \"=== TESTING NGINX HEALTH ENDPOINTS ===\"",
    "echo \"Testing localhost:80...\"",
    "curl -I localhost:80 2>/dev/null || echo \"Failed to connect to localhost:80\"",
    "echo \"\"",
    "echo \"Testing container internal health...\"",
    "sudo docker exec nginx_proxy curl -I localhost 2>/dev/null || echo \"Failed internal health check\"",
    "echo \"\"",
    "echo \"Testing backend connectivity from nginx...\"",
    "sudo docker exec nginx_proxy curl -I sms_backend:8900 2>/dev/null || echo \"Cannot reach backend from nginx\"",
    "echo \"\"",
    "echo \"Testing frontend connectivity from nginx...\"", 
    "sudo docker exec nginx_proxy curl -I sms_frontend:80 2>/dev/null || echo \"Cannot reach frontend from nginx\""
]'

echo "🔍 Step 5: Check network connectivity..."
execute_remote_command "Network Connectivity Check" '[
    "#!/bin/bash",
    "cd /app/sms-seller-connect",
    "echo \"=== DOCKER NETWORK STATUS ===\"",
    "sudo docker network ls",
    "echo \"\"",
    "echo \"=== CONTAINER NETWORK INSPECTION ===\"",
    "NETWORK_NAME=$(sudo docker-compose ps -q nginx_proxy | xargs sudo docker inspect --format=\"{{range .NetworkSettings.Networks}}{{.NetworkMode}}{{end}}\" 2>/dev/null || echo \"default\")",
    "echo \"Network: $NETWORK_NAME\"",
    "echo \"\"",
    "echo \"=== CONTAINER IP ADDRESSES ===\"",
    "sudo docker-compose ps -q | xargs sudo docker inspect --format=\"{{.Name}}: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}\" 2>/dev/null || echo \"Cannot get IPs\""
]'

echo "🔧 Step 6: Attempt nginx health fix..."
execute_remote_command "Nginx Health Fix Attempt" '[
    "#!/bin/bash",
    "cd /app/sms-seller-connect",
    "echo \"=== ATTEMPTING NGINX FIXES ===\"",
    "echo \"1. Restarting nginx container...\"",
    "sudo docker-compose restart nginx_proxy",
    "sleep 10",
    "echo \"\"",
    "echo \"2. Checking status after restart...\"",
    "sudo docker-compose ps nginx_proxy",
    "echo \"\"",
    "echo \"3. Testing health after restart...\"",
    "curl -I localhost:80 2>/dev/null && echo \"✅ Health check passed\" || echo \"❌ Health check still failing\"",
    "echo \"\"",
    "echo \"4. If still unhealthy, checking for nginx syntax errors...\"",
    "sudo docker exec nginx_proxy nginx -t 2>&1 || echo \"Nginx configuration has syntax errors\""
]'

echo "🎯 NGINX DIAGNOSTIC COMPLETE!"
echo ""
echo "📋 Common fixes if nginx is still unhealthy:"
echo "  1. Nginx configuration syntax errors"
echo "  2. Backend/frontend containers not reachable"
echo "  3. Port conflicts or binding issues"
echo "  4. SSL/TLS certificate problems"
echo "  5. Network connectivity between containers"
echo ""
echo "💡 If nginx is still unhealthy, check the diagnostic output above for specific errors." 