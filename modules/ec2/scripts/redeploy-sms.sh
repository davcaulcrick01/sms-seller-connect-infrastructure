# Update nginx configuration with CORS headers to fix frontend API access
echo "🔄 Updating nginx configuration with CORS headers..."
sudo docker exec nginx_proxy sh -c '
    # Add CORS headers to nginx configuration dynamically
    sed -i "/proxy_redirect off;/a\\
        # CORS Configuration for API\\
        add_header \"Access-Control-Allow-Origin\" \"*\" always;\\
        add_header \"Access-Control-Allow-Methods\" \"GET, POST, PUT, DELETE, PATCH, OPTIONS\" always;\\
        add_header \"Access-Control-Allow-Headers\" \"Origin, X-Requested-With, Content-Type, Accept, Authorization, Cache-Control, Pragma, Expires, X-API-Key\" always;\\
        add_header \"Access-Control-Allow-Credentials\" \"true\" always;\\
        add_header \"Access-Control-Max-Age\" \"3600\" always;" /etc/nginx/nginx.conf
    
    # Reload nginx to apply changes
    nginx -s reload
' || echo "❌ Failed to update nginx configuration"

echo "✅ Nginx configuration updated with CORS headers" 