#!/bin/bash

echo "🔧 FIXING NGINX SERVER NAME CONFLICTS"
echo "====================================="
echo ""

# Since you're on the EC2 instance directly, run these commands:
echo "📋 Run these commands on your EC2 instance:"
echo ""

echo "1. First, check the current nginx configuration:"
echo "   docker exec nginx_proxy cat /etc/nginx/conf.d/default.conf"
echo ""

echo "2. Check if there are multiple config files:"
echo "   docker exec nginx_proxy ls -la /etc/nginx/conf.d/"
echo ""

echo "3. Test nginx configuration for syntax errors:"
echo "   docker exec nginx_proxy nginx -t"
echo ""

echo "4. Fix the conflicting server names by editing the config:"
echo "   docker exec -it nginx_proxy vi /etc/nginx/conf.d/default.conf"
echo ""

echo "5. Or create a new corrected configuration:"
cat << 'EOF'
docker exec nginx_proxy sh -c 'cat > /etc/nginx/conf.d/default.conf << "NGINX_EOF"
server {
    listen 80;
    server_name sms.typerelations.com;
    
    # Frontend requests
    location / {
        proxy_pass http://sms_frontend:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # API requests
    location /api/ {
        proxy_pass http://sms_backend:8900/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}

server {
    listen 80;
    server_name api.sms.typerelations.com;
    
    # All API requests
    location / {
        proxy_pass http://sms_backend:8900;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
NGINX_EOF'
EOF

echo ""
echo "6. Test the new configuration:"
echo "   docker exec nginx_proxy nginx -t"
echo ""

echo "7. Reload nginx with the new configuration:"
echo "   docker exec nginx_proxy nginx -s reload"
echo ""

echo "8. Check if nginx is now healthy:"
echo "   docker ps"
echo "   curl -I localhost:80"
echo ""

echo "🎯 ALTERNATIVE: Quick fix command (run this directly on EC2):"
echo ""
echo "docker exec nginx_proxy sh -c 'nginx -t && nginx -s reload' && sleep 5 && docker ps && curl -I localhost:80"
echo ""

echo "💡 The issue is that nginx has duplicate server blocks for the same domains."
echo "   This causes conflicts and makes the health check fail."
echo ""
echo "✅ After fixing, both domains should work:"
echo "   - https://sms.typerelations.com (frontend)"
echo "   - https://api.sms.typerelations.com (backend API)" 