#!/bin/bash

# Immediate CORS Fix Script
# This script fixes the CORS issue on running containers without needing redeploy

echo "🚀 SMS Seller Connect - Immediate CORS Fix"
echo "============================================"

# Function to check if a container is running
check_container() {
    local container_name=$1
    if docker ps | grep -q "$container_name"; then
        echo "✅ Container $container_name is running"
        return 0
    else
        echo "❌ Container $container_name is not running"
        return 1
    fi
}

# Function to add CORS headers to nginx
fix_nginx_cors() {
    echo "🔧 Adding CORS headers to nginx configuration..."
    
    # First, backup the current nginx config
    docker exec nginx_proxy cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    
    # Create a temporary nginx config with CORS headers
    docker exec nginx_proxy sh -c 'cat > /tmp/cors_fix.conf << '\''EOF'\''
# CORS headers for API endpoints
location ~ ^/api/ {
    add_header '\''Access-Control-Allow-Origin'\'' '\''*'\'' always;
    add_header '\''Access-Control-Allow-Methods'\'' '\''GET, POST, PUT, DELETE, PATCH, OPTIONS'\'' always;
    add_header '\''Access-Control-Allow-Headers'\'' '\''Origin, X-Requested-With, Content-Type, Accept, Authorization, Cache-Control, Pragma, Expires, X-API-Key'\'' always;
    add_header '\''Access-Control-Allow-Credentials'\'' '\''true'\'' always;
    add_header '\''Access-Control-Max-Age'\'' '\''3600'\'' always;
    
    # Handle preflight OPTIONS requests
    if ($request_method = '\''OPTIONS'\'') {
        add_header '\''Access-Control-Allow-Origin'\'' '\''*'\'' always;
        add_header '\''Access-Control-Allow-Methods'\'' '\''GET, POST, PUT, DELETE, PATCH, OPTIONS'\'' always;
        add_header '\''Access-Control-Allow-Headers'\'' '\''Origin, X-Requested-With, Content-Type, Accept, Authorization, Cache-Control, Pragma, Expires, X-API-Key'\'' always;
        add_header '\''Access-Control-Allow-Credentials'\'' '\''true'\'' always;
        add_header '\''Access-Control-Max-Age'\'' '\''3600'\'' always;
        add_header '\''Content-Length'\'' '\''0'\'';
        add_header '\''Content-Type'\'' '\''text/plain charset=UTF-8'\'';
        return 204;
    }
    
    proxy_pass http://sms_backend;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
EOF'
    
    # Insert CORS configuration into the API server block
    docker exec nginx_proxy sh -c 'sed -i "/# API routes/r /tmp/cors_fix.conf" /etc/nginx/nginx.conf'
    
    # Test nginx configuration
    if docker exec nginx_proxy nginx -t; then
        echo "✅ Nginx configuration is valid"
        # Reload nginx
        docker exec nginx_proxy nginx -s reload
        echo "✅ Nginx reloaded with CORS headers"
    else
        echo "❌ Nginx configuration is invalid, restoring backup"
        docker exec nginx_proxy cp /etc/nginx/nginx.conf.backup /etc/nginx/nginx.conf
        return 1
    fi
}

# Function to restart backend container with proper environment
fix_backend_config() {
    echo "🔧 Checking backend container configuration..."
    
    # Check if backend is responding to health checks
    if docker exec sms_backend wget --quiet --tries=1 --timeout=5 --spider http://localhost:8900/health; then
        echo "✅ Backend health check is working"
    else
        echo "⚠️ Backend health check failed, restarting container..."
        docker restart sms_backend
        sleep 30
    fi
}

# Function to verify the fix
verify_fix() {
    echo "🔍 Verifying CORS fix..."
    
    # Test CORS preflight request
    local api_domain="${SMS_API_DOMAIN:-api.sms.typerelations.com}"
    echo "Testing CORS on https://$api_domain..."
    
    curl -I -X OPTIONS "https://$api_domain/api/health" \
        -H "Origin: https://sms.typerelations.com" \
        -H "Access-Control-Request-Method: GET" \
        -H "Access-Control-Request-Headers: Content-Type,Authorization" \
        --connect-timeout 10 --max-time 30 2>/dev/null | grep -i "access-control"
    
    if [ $? -eq 0 ]; then
        echo "✅ CORS headers are present"
    else
        echo "⚠️ CORS headers may not be working properly"
    fi
}

# Main execution
echo "Starting CORS fix process..."

# Check if containers are running
if check_container "nginx_proxy" && check_container "sms_backend"; then
    echo "✅ All required containers are running"
    
    # Fix nginx CORS
    fix_nginx_cors
    
    # Fix backend config
    fix_backend_config
    
    # Verify the fix
    verify_fix
    
    echo ""
    echo "🎉 CORS fix complete!"
    echo "Try accessing the frontend again to see if the CORS error is resolved."
    echo ""
    echo "If the issue persists, you may need to:"
    echo "1. Redeploy the containers with the updated configuration"
    echo "2. Check if the frontend is using the correct API URL"
    echo "3. Verify DNS resolution for the domains"
    
else
    echo "❌ Required containers are not running. Please start the containers first."
    exit 1
fi 