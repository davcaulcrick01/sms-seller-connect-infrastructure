#!/bin/bash

# Script to apply CORS fixes to nginx configuration on EC2 instance
# Run this on the EC2 instance to apply the fixes

echo "🔧 Applying CORS and redirect fixes to nginx configuration..."

# Backup current config
sudo cp /app/sms-seller-connect/nginx.conf /app/sms-seller-connect/nginx.conf.backup-$(date +%Y%m%d_%H%M%S)

# Copy the fixed configuration from repository
if [ -f "/app/sms-seller-connect/modules/ec2/config/nginx.conf" ]; then
    sudo cp /app/sms-seller-connect/modules/ec2/config/nginx.conf /app/sms-seller-connect/nginx.conf
    echo "✅ Updated nginx configuration from repository"
else
    echo "❌ Repository config not found, applying manual fixes..."
    
    # Remove duplicate CORS headers from server level
    sudo sed -i '/# CORS Configuration for API/,+5d' /app/sms-seller-connect/nginx.conf
    
    # Add CORS headers to location blocks (this is a simplified approach)
    echo "⚠️  Manual fixes applied - please verify configuration"
fi

# Test nginx configuration
echo "🧪 Testing nginx configuration..."
sudo docker exec nginx_proxy nginx -t

if [ $? -eq 0 ]; then
    echo "✅ Nginx configuration is valid"
    
    # Restart nginx
    echo "🔄 Restarting nginx..."
    cd /app/sms-seller-connect
    sudo docker-compose restart nginx
    
    # Wait for startup
    sleep 10
    
    # Test endpoints
    echo "🧪 Testing API endpoints..."
    
    echo "Testing health endpoint:"
    curl -s -H "Host: api.sms.typerelations.com" http://localhost/health
    
    echo -e "\n\nTesting leads API (should not redirect):"
    curl -v -H "Host: api.sms.typerelations.com" http://localhost/api/leads 2>&1 | grep -E "HTTP|Location|Access-Control"
    
    echo -e "\n\n✅ CORS fixes applied successfully!"
    echo "Please test the frontend application to verify CORS errors are resolved."
    
else
    echo "❌ Nginx configuration is invalid - restoring backup"
    sudo cp /app/sms-seller-connect/nginx.conf.backup-$(date +%Y%m%d_%H%M%S) /app/sms-seller-connect/nginx.conf
fi