#!/bin/bash

# ALB Health Check Script for SMS Seller Connect
# Tests both backend and frontend containers
# Returns HTTP 200 only if ALL containers are healthy

set -e

# Configuration
BACKEND_URL="http://sms_backend:8900/health"
FRONTEND_URL="http://sms_frontend:8082"
TIMEOUT=5
MAX_RETRIES=2

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    echo "[$timestamp] [$level] HealthCheck: $message"
}

# Function to check a single service
check_service() {
    local service_name="$1"
    local service_url="$2"
    local retry_count=0
    
    while [ $retry_count -lt $MAX_RETRIES ]; do
        if curl -f -s --max-time $TIMEOUT "$service_url" > /dev/null 2>&1; then
            log_message "INFO" "✅ $service_name is healthy"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $MAX_RETRIES ]; then
            log_message "WARN" "⚠️ $service_name check failed, retrying ($retry_count/$MAX_RETRIES)..."
            sleep 1
        fi
    done
    
    log_message "ERROR" "❌ $service_name is unhealthy after $MAX_RETRIES retries"
    return 1
}

# Function to check Docker containers are running
check_containers_running() {
    local containers=("sms_backend" "sms_frontend" "nginx_proxy")
    
    for container in "${containers[@]}"; do
        if ! docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            log_message "ERROR" "❌ Container '$container' is not running"
            return 1
        fi
    done
    
    log_message "INFO" "✅ All required containers are running"
    return 0
}

# Main health check function
perform_health_check() {
    local all_healthy=true
    
    log_message "INFO" "Starting comprehensive health check..."
    
    # Check if containers are running
    if ! check_containers_running; then
        return 1
    fi
    
    # Check backend health
    if ! check_service "SMS Backend" "$BACKEND_URL"; then
        all_healthy=false
    fi
    
    # Check frontend health  
    if ! check_service "SMS Frontend" "$FRONTEND_URL"; then
        all_healthy=false
    fi
    
    if [ "$all_healthy" = true ]; then
        log_message "INFO" "🎉 All services are healthy"
        return 0
    else
        log_message "ERROR" "💥 One or more services are unhealthy"
        return 1
    fi
}

# HTTP response function for ALB
send_http_response() {
    local status_code="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    # Send HTTP response
    cat << EOF
HTTP/1.1 $status_code
Content-Type: application/json
Content-Length: $((${#message} + 50))
Connection: close

{
  "status": "$message",
  "timestamp": "$timestamp",
  "containers": ["sms_backend", "sms_frontend", "nginx_proxy"]
}
EOF
}

# Main execution
main() {
    # If called with --http flag, send HTTP response (for direct ALB calls)
    if [ "$1" = "--http" ]; then
        if perform_health_check; then
            send_http_response "200 OK" "healthy"
        else
            send_http_response "503 Service Unavailable" "unhealthy"
        fi
    else
        # Regular script execution (for cron/manual testing)
        if perform_health_check; then
            echo "healthy"
            exit 0
        else
            echo "unhealthy"
            exit 1
        fi
    fi
}

# Run main function with all arguments
main "$@" 