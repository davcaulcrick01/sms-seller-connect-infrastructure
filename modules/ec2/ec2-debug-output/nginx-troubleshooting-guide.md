# SMS Seller Connect - Nginx Troubleshooting Guide

## 🎯 PROBLEM SUMMARY
- **Issue**: nginx proxy failing with config error on line 28
- **Error**: `nginx: [emerg] invalid value "must-revalidate" in /etc/nginx/nginx.conf:28`
- **Impact**: All external access blocked (domains and direct IP)
- **Services Affected**: Frontend and API access

## 🔍 STEP-BY-STEP TROUBLESHOOTING

### STEP 1: SSH into EC2 Instance
```bash
ssh -i car-rental-key.pem ec2-user@98.81.70.146
```

### STEP 2: Check Current Container Status
```bash
cd /app/sms-seller-connect
sudo docker-compose ps
```

### STEP 3: View Nginx Configuration File
```bash
# Check the current nginx config that's causing the error
sudo docker-compose exec nginx_proxy cat /etc/nginx/nginx.conf

# Or if container is not running:
cat nginx.conf
```

### STEP 4: Examine the Specific Error Line
```bash
# Look at line 28 specifically
sed -n '25,35p' nginx.conf
```

### STEP 5: Check Nginx Logs in Real-Time
```bash
# Follow nginx logs to see exact error
sudo docker-compose logs -f nginx

# Or check recent logs
sudo docker-compose logs --tail 50 nginx
```

### STEP 6: Validate Nginx Configuration Syntax
```bash
# Test nginx config without starting the service
sudo docker run --rm -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro nginx:alpine nginx -t
```

### STEP 7: Fix the Configuration Issue

**Common "must-revalidate" errors and fixes:**

**A) Cache-Control Header Issue (Most Likely)**
Look for lines like:
```nginx
add_header Cache-Control "no-cache, must-revalidate";
```
Should be:
```nginx
add_header Cache-Control "no-cache, must-revalidate" always;
```

**B) Proxy Cache Issue**
Look for:
```nginx
proxy_cache_control must-revalidate;
```
Should be:
```nginx
proxy_cache_control "must-revalidate";
```

**C) Expires Directive Issue**
Look for:
```nginx
expires must-revalidate;
```
Should be removed or replaced with:
```nginx
expires -1;
add_header Cache-Control "no-cache, must-revalidate" always;
```

### STEP 8: Apply the Fix
```bash
# Edit the nginx.conf file
sudo nano nginx.conf

# Or use sed to fix common issues:
# Fix missing quotes around must-revalidate
sudo sed -i 's/must-revalidate/"must-revalidate"/g' nginx.conf

# Fix missing always keyword
sudo sed -i 's/Cache-Control "no-cache, must-revalidate";/Cache-Control "no-cache, must-revalidate" always;/g' nginx.conf
```

### STEP 9: Test Configuration Again
```bash
# Validate the fixed config
sudo docker run --rm -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro nginx:alpine nginx -t
```

### STEP 10: Restart Nginx Service
```bash
# Restart just the nginx container
sudo docker-compose restart nginx

# Or restart all services
sudo docker-compose down
sudo docker-compose up -d
```

### STEP 11: Verify Fix
```bash
# Check container status
sudo docker-compose ps

# Check nginx logs
sudo docker-compose logs nginx

# Test external access
curl -I http://localhost
curl -I http://98.81.70.146
```

## 🛠️ ALTERNATIVE TROUBLESHOOTING METHODS

### Method A: Quick SSH Commands (Run from Local)
```bash
# Check nginx config remotely
ssh -i car-rental-key.pem ec2-user@98.81.70.146 'cd /app/sms-seller-connect && cat nginx.conf | grep -n "must-revalidate"'

# Check specific line 28
ssh -i car-rental-key.pem ec2-user@98.81.70.146 'cd /app/sms-seller-connect && sed -n "28p" nginx.conf'

# View nginx logs
ssh -i car-rental-key.pem ec2-user@98.81.70.146 'cd /app/sms-seller-connect && sudo docker-compose logs --tail 20 nginx'
```

### Method B: Download and Fix Config Locally
```bash
# Download nginx config to fix locally
scp -i car-rental-key.pem ec2-user@98.81.70.146:/app/sms-seller-connect/nginx.conf ./nginx-backup.conf

# Edit locally, then upload back
# scp -i car-rental-key.pem ./nginx-fixed.conf ec2-user@98.81.70.146:/app/sms-seller-connect/nginx.conf
```

### Method C: Temporary Bypass (Testing Only)
```bash
# Temporarily use default nginx config for testing
ssh -i car-rental-key.pem ec2-user@98.81.70.146 'cd /app/sms-seller-connect && sudo docker run -d --name temp-nginx -p 8080:80 nginx:alpine'

# Test if basic nginx works
curl http://98.81.70.146:8080
```

## 🔧 COMMON FIXES FOR LINE 28 ERRORS

1. **Missing Quotes**: `must-revalidate` → `"must-revalidate"`
2. **Missing Always**: `Cache-Control "no-cache, must-revalidate";` → `Cache-Control "no-cache, must-revalidate" always;`
3. **Wrong Directive**: `expires must-revalidate;` → `expires -1;`
4. **Proxy Issue**: `proxy_cache_control must-revalidate;` → `proxy_cache_control "must-revalidate";`

## 📊 VERIFICATION CHECKLIST

After applying fixes:
- [ ] Nginx config syntax test passes
- [ ] Nginx container starts successfully  
- [ ] No error logs from nginx
- [ ] HTTP response from localhost
- [ ] HTTP response from external IP
- [ ] Domain resolution working
- [ ] Frontend loads properly
- [ ] API endpoints respond

## 🚨 EMERGENCY ROLLBACK

If fixes break something worse:
```bash
# Stop all containers
sudo docker-compose down

# Restore from backup (if you made one)
cp nginx-backup.conf nginx.conf

# Or use minimal working config
cat > nginx.conf << 'MINIMAL_CONFIG'
events {
    worker_connections 1024;
}
http {
    upstream backend {
        server sms_backend:8900;
    }
    upstream frontend {
        server sms_frontend:8082;
    }
    server {
        listen 80;
        location /api/ {
            proxy_pass http://backend;
        }
        location / {
            proxy_pass http://frontend;
        }
    }
}
MINIMAL_CONFIG

# Restart with minimal config
sudo docker-compose up -d
```

## 📞 NEXT STEPS

1. **Immediate**: Fix nginx.conf line 28 syntax error
2. **Verify**: Test external access works
3. **Monitor**: Check health checks start working
4. **Document**: Save working nginx.conf as backup
