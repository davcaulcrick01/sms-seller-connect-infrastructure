#!/bin/bash
# SMS Seller Connect Maintenance Script
# This script monitors the health of the services and restarts them if needed

LOG_FILE="/var/log/sms-seller-connect-maintenance.log"
APP_DIR="/app/sms-seller-connect"

# Function to log messages with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to check if a service is healthy
check_service_health() {
    local service_name="$1"
    local health_url="$2"
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if curl -f -s --max-time 10 "$health_url" > /dev/null 2>&1; then
            return 0  # Service is healthy
        fi
        retry_count=$((retry_count + 1))
        sleep 2
    done
    
    return 1  # Service is unhealthy
}

# Function to restart a service
restart_service() {
    local service_name="$1"
    log_message "Restarting $service_name service..."
    
    cd "$APP_DIR" || {
        log_message "ERROR: Cannot change to $APP_DIR directory"
        return 1
    }
    
    sudo docker-compose restart "$service_name"
    sleep 10  # Give service time to start
    
    log_message "$service_name service restart completed"
}

# Function to check and restart services if needed
check_and_restart() {
    cd "$APP_DIR" || {
        log_message "ERROR: Cannot change to $APP_DIR directory"
        exit 1
    }
    
    log_message "Starting health check..."
    
    # Check backend service
    if ! check_service_health "backend" "http://localhost:8900/health"; then
        log_message "Backend service is unhealthy, restarting..."
        restart_service "backend"
        
        # Wait and check again
        sleep 15
        if check_service_health "backend" "http://localhost:8900/health"; then
            log_message "Backend service restart successful"
        else
            log_message "ERROR: Backend service still unhealthy after restart"
        fi
    else
        log_message "Backend service is healthy"
    fi
    
    # Check frontend service
    if ! check_service_health "frontend" "http://localhost:8082"; then
        log_message "Frontend service is unhealthy, restarting..."
        restart_service "frontend"
        
        # Wait and check again
        sleep 15
        if check_service_health "frontend" "http://localhost:8082"; then
            log_message "Frontend service restart successful"
        else
            log_message "ERROR: Frontend service still unhealthy after restart"
        fi
    else
        log_message "Frontend service is healthy"
    fi
    
    # Clean up old logs (keep last 7 days)
    find /app/logs -name "*.log" -mtime +7 -delete 2>/dev/null || true
    find /var/log -name "sms-seller-connect-*.log" -size +100M -exec truncate -s 50M {} \; 2>/dev/null || true
    
    # Check disk space and alert if low
    disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 85 ]; then
        log_message "WARNING: Disk usage is at ${disk_usage}%"
    fi
    
    # Check memory usage
    memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$memory_usage" -gt 90 ]; then
        log_message "WARNING: Memory usage is at ${memory_usage}%"
    fi
    
    log_message "Health check completed"
}

# Function to update services with latest images
update_services() {
    log_message "Updating services with latest images..."
    
    cd "$APP_DIR" || {
        log_message "ERROR: Cannot change to $APP_DIR directory"
        exit 1
    }
    
    # Pull latest images
    sudo docker-compose pull
    
    # Restart services with new images
    sudo docker-compose up -d
    
    log_message "Service update completed"
}

# Main execution
case "${1:-check}" in
    "check")
        check_and_restart
        ;;
    "update")
        update_services
        ;;
    "restart")
        log_message "Manual restart requested"
        restart_service "backend"
        restart_service "frontend"
        ;;
    *)
        echo "Usage: $0 {check|update|restart}"
        echo "  check   - Check service health and restart if needed (default)"
        echo "  update  - Pull latest images and restart services"
        echo "  restart - Force restart all services"
        exit 1
        ;;
esac 