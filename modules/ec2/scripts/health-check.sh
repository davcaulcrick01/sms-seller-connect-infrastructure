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

# Function to check background services running inside backend container
check_background_services() {
    local all_services_healthy=true
    local logs_dir="/app/logs"
    
    log_message "INFO" "🔍 Checking background services with live activity..."
    
    # Check if we're inside the backend container or need to exec into it
    if [ -d "$logs_dir" ]; then
        # We're inside the container
        local pid_dir="$logs_dir"
        local check_mode="internal"
    else
        # We're outside, need to check via docker exec
        local pid_dir="/tmp/sms_backend_logs"
        local check_mode="external"
        # Copy PID files from container to temp location for checking
        docker exec sms_backend sh -c "mkdir -p /tmp/logs_copy && cp -r /app/logs/* /tmp/logs_copy/ 2>/dev/null || true" 2>/dev/null || true
        docker cp sms_backend:/tmp/logs_copy/. "$pid_dir/" 2>/dev/null || mkdir -p "$pid_dir"
    fi
    
    # Define background services to check
    local services=(
        "scheduled-messages:📨 Scheduled Messages Service:scheduled_messages.log"
        "ai-processor:🤖 AI Response Processor:ai_processor.log"
    )
    
    for service_info in "${services[@]}"; do
        local service_name="${service_info%%:*}"
        local temp="${service_info#*:}"
        local display_name="${temp%%:*}"
        local log_file="${service_info##*:}"
        local pid_file="$pid_dir/${service_name}.pid"
        local full_log_path="$logs_dir/$log_file"
        
        log_message "INFO" "Checking $display_name..."
        
        # Check if PID file exists and process is running
        local pid_status="❌ Not Running"
        local process_running=false
        
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file" 2>/dev/null)
            if [ ! -z "$pid" ]; then
                # Check if process is running (either locally or in container)
                if [ "$check_mode" = "internal" ]; then
                    if kill -0 "$pid" 2>/dev/null; then
                        pid_status="✅ Running (PID: $pid)"
                        process_running=true
                    else
                        pid_status="⚠️ Stale PID: $pid"
                    fi
                else
                    if docker exec sms_backend kill -0 "$pid" 2>/dev/null; then
                        pid_status="✅ Running (PID: $pid)"
                        process_running=true
                    else
                        pid_status="⚠️ Stale PID: $pid"
                    fi
                fi
            else
                pid_status="⚠️ Empty PID file"
            fi
        else
            pid_status="❌ No PID file"
        fi
        
        # Get recent log activity
        local log_activity="No recent activity"
        local log_status="📝 Log Status: "
        
        if [ "$check_mode" = "internal" ] && [ -f "$full_log_path" ]; then
            # We're inside container, read log directly
            local log_size=$(stat -f%z "$full_log_path" 2>/dev/null || stat -c%s "$full_log_path" 2>/dev/null || echo "0")
            local last_modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$full_log_path" 2>/dev/null || stat -c "%y" "$full_log_path" 2>/dev/null | cut -d'.' -f1 || echo "unknown")
            
            if [ "$log_size" -gt 0 ]; then
                # Get last 2 lines of log
                local recent_logs=$(tail -n 2 "$full_log_path" 2>/dev/null | tr '\n' ' | ' | sed 's/ | $//')
                if [ ! -z "$recent_logs" ]; then
                    log_activity="$recent_logs"
                    log_status="📝 Log: ${log_size} bytes, modified: $last_modified"
                else
                    log_status="📝 Log: Empty file (${log_size} bytes)"
                fi
            else
                log_status="📝 Log: File not found or empty"
            fi
        elif [ "$check_mode" = "external" ]; then
            # We're outside container, get log via docker exec
            local log_info=$(docker exec sms_backend sh -c "
                if [ -f '$full_log_path' ]; then
                    size=\$(stat -c%s '$full_log_path' 2>/dev/null || echo '0')
                    modified=\$(stat -c '%y' '$full_log_path' 2>/dev/null | cut -d'.' -f1 || echo 'unknown')
                    recent=\$(tail -n 2 '$full_log_path' 2>/dev/null | tr '\n' ' | ' | sed 's/ | $//' || echo '')
                    echo \"SIZE:\$size|MODIFIED:\$modified|RECENT:\$recent\"
                else
                    echo 'SIZE:0|MODIFIED:unknown|RECENT:'
                fi
            " 2>/dev/null || echo "SIZE:0|MODIFIED:unknown|RECENT:")
            
            local log_size=$(echo "$log_info" | cut -d'|' -f1 | cut -d':' -f2)
            local last_modified=$(echo "$log_info" | cut -d'|' -f2 | cut -d':' -f2-)
            local recent_logs=$(echo "$log_info" | cut -d'|' -f3 | cut -d':' -f2-)
            
            if [ "$log_size" -gt 0 ] && [ ! -z "$recent_logs" ]; then
                log_activity="$recent_logs"
                log_status="📝 Log: ${log_size} bytes, modified: $last_modified"
            elif [ "$log_size" -gt 0 ]; then
                log_status="📝 Log: ${log_size} bytes (no recent entries)"
            else
                log_status="📝 Log: File not found or empty"
            fi
        fi
        
        # Log the detailed status
        log_message "INFO" "  $display_name"
        log_message "INFO" "    Status: $pid_status"
        log_message "INFO" "    $log_status"
        if [ "$log_activity" != "No recent activity" ]; then
            log_message "INFO" "    Recent: $log_activity"
        else
            log_message "INFO" "    Recent: No recent activity"
        fi
        
        # Update overall health status
        if [ "$process_running" = false ]; then
            all_services_healthy=false
        fi
    done
    
    # Cleanup temp directory if created
    [ -d "/tmp/sms_backend_logs" ] && rm -rf "/tmp/sms_backend_logs"
    
    if [ "$all_services_healthy" = true ]; then
        log_message "INFO" "✅ All background services are running with active logs"
        return 0
    else
        log_message "WARN" "⚠️ Some background services are not running properly"
        return 1
    fi
}

# Main health check function
perform_health_check() {
    local all_healthy=true
    local background_services_healthy=true
    
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
    
    # Check background services (non-critical for ALB health)
    if ! check_background_services; then
        background_services_healthy=false
        log_message "WARN" "⚠️ Background services check failed (non-critical)"
    fi
    
    if [ "$all_healthy" = true ]; then
        if [ "$background_services_healthy" = true ]; then
            log_message "INFO" "🎉 All services and background processes are healthy"
        else
            log_message "INFO" "🎉 Core services are healthy (background services have issues)"
        fi
        return 0
    else
        log_message "ERROR" "💥 One or more core services are unhealthy"
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