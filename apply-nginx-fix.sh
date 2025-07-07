#!/bin/bash
set -e

echo "🔧 Applying nginx configuration fix to EC2 instance..."

INSTANCE_ID="i-0072d9109457c2539"

# Send the fixed nginx configuration
COMMAND_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "cd /app/sms-seller-connect",
    "echo \"Creating fixed nginx configuration...\"",
    "cat > /tmp/nginx-default.conf << \"EOF\"",
    "server {",
    "    listen 80;",
    "    server_name sms.typerelations.com;",
    "    location / {",
    "        proxy_pass http://sms_frontend:80;",
    "        proxy_set_header Host $host;",
    "        proxy_set_header X-Real-IP $remote_addr;",
    "        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;",
    "        proxy_set_header X-Forwarded-Proto $scheme;",
    "    }",
    "    location /api/ {",
    "        proxy_pass http://sms_backend:8900/api/;",
    "        proxy_set_header Host $host;",
    "        proxy_set_header X-Real-IP $remote_addr;",
    "        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;",
    "        proxy_set_header X-Forwarded-Proto $scheme;",
    "    }",
    "    location /health {",
    "        access_log off;",
    "        return 200 \"healthy\\n\";",
    "        add_header Content-Type text/plain;",
    "    }",
    "}",
    "server {",
    "    listen 80;",
    "    server_name api.sms.typerelations.com;",
    "    location / {",
    "        proxy_pass http://sms_backend:8900;",
    "        proxy_set_header Host $host;",
    "        proxy_set_header X-Real-IP $remote_addr;",
    "        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;",
    "        proxy_set_header X-Forwarded-Proto $scheme;",
    "    }",
    "    location /health {",
    "        access_log off;",
    "        return 200 \"healthy\\n\";",
    "        add_header Content-Type text/plain;",
    "    }",
    "}",
    "EOF",
    "echo \"Applying configuration to nginx container...\"",
    "docker cp /tmp/nginx-default.conf nginx_proxy:/etc/nginx/conf.d/default.conf",
    "echo \"Testing nginx configuration...\"",
    "docker exec nginx_proxy nginx -t",
    "echo \"Reloading nginx...\"",
    "docker exec nginx_proxy nginx -s reload",
    "echo \"Waiting for nginx to stabilize...\"",
    "sleep 10",
    "echo \"Checking container status...\"",
    "docker ps",
    "echo \"Testing health endpoint...\"",
    "curl -I localhost:80",
    "echo \"✅ Nginx configuration applied successfully!\""
  ]' \
  --comment "Apply nginx configuration fix" \
  --query 'Command.CommandId' \
  --output text)

echo "Command sent: $COMMAND_ID"
echo "⏳ Waiting for completion..."

# Wait for command to complete
aws ssm wait command-executed --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID"

echo "📊 Command output:"
aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" --query 'StandardOutputContent' --output text

echo "🎉 Nginx fix applied! Check container status with: docker ps" 