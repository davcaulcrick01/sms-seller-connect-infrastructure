#!/bin/bash

# ===============================================
# EC2 Docker Logs Collector
# Pulls all Docker Compose logs from SMS Seller Connect EC2 instance
# ===============================================

set -e  # Exit on any error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
SSH_KEY="../car-rental-key.pem"  # SSH key is in ec2 directory
SSH_USER="ec2-user"
SSH_HOST="98.81.70.146"
REMOTE_DIR="/app/sms-seller-connect"
LOCAL_OUTPUT_DIR="../ec2-debug-output"  # Relative to scripts directory

# Create timestamp for this collection session
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${BOLD}${BLUE}========================================${NC}"
echo -e "${BOLD}${BLUE}   EC2 Docker Logs Collector${NC}"
echo -e "${BOLD}${BLUE}========================================${NC}"
echo -e "${CYAN}SSH Target: ${SSH_USER}@${SSH_HOST}${NC}"
echo -e "${CYAN}Remote Dir: ${REMOTE_DIR}${NC}"
echo -e "${CYAN}Local Dir:  ${LOCAL_OUTPUT_DIR}${NC}"
echo -e "${CYAN}SSH Key:    ${SSH_KEY}${NC}"
echo -e "${CYAN}Session:    ${TIMESTAMP}${NC}"
echo ""

# Function to log with timestamp
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case $level in
        "INFO")  echo -e "${BLUE}[$timestamp] INFO:${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[$timestamp] SUCCESS:${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}[$timestamp] WARNING:${NC} $message" ;;
        "ERROR") echo -e "${RED}[$timestamp] ERROR:${NC} $message" ;;
        *) echo "[$timestamp] $message" ;;
    esac
}

# Function to execute SSH command with error handling
execute_ssh_command() {
    local description="$1"
    local remote_command="$2"
    local output_file="$3"
    local step_num="$4"
    local total_steps="$5"
    
    echo -e "${PURPLE}[$step_num/$total_steps]${NC} $description..."
    
    local full_ssh_command="ssh -i $SSH_KEY $SSH_USER@$SSH_HOST 'cd $REMOTE_DIR && $remote_command'"
    
    if eval "$full_ssh_command" > "$output_file" 2>&1; then
        local file_size=$(wc -l < "$output_file" 2>/dev/null || echo "0")
        log_message "SUCCESS" "$description completed (${file_size} lines saved)"
        return 0
    else
        log_message "ERROR" "$description failed"
        echo "Error details saved to: $output_file"
        return 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    log_message "INFO" "Checking prerequisites..."
    
    # Check if SSH key exists
    if [[ ! -f "$SSH_KEY" ]]; then
        log_message "ERROR" "SSH key not found: $SSH_KEY"
        log_message "INFO" "Looking for key in current directory..."
        if [[ -f "car-rental-key.pem" ]]; then
            SSH_KEY="car-rental-key.pem"
            log_message "SUCCESS" "Found SSH key in current directory"
        elif [[ -f "../car-rental-key.pem" ]]; then
            SSH_KEY="../car-rental-key.pem"
            log_message "SUCCESS" "Found SSH key in parent directory"
        else
            log_message "ERROR" "SSH key not found in any expected location"
            exit 1
        fi
    else
        log_message "SUCCESS" "SSH key found: $SSH_KEY"
    fi
    
    # Create output directory
    mkdir -p "$LOCAL_OUTPUT_DIR"
    log_message "SUCCESS" "Output directory ready: $LOCAL_OUTPUT_DIR"
    
    # Test SSH connection
    log_message "INFO" "Testing SSH connection..."
    if ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "echo 'SSH connection test successful'" >/dev/null 2>&1; then
        log_message "SUCCESS" "SSH connection verified"
    else
        log_message "ERROR" "Cannot connect to SSH server"
        log_message "INFO" "Check if the SSH key has correct permissions (should be 600)"
        exit 1
    fi
    
    # Test Docker Compose on remote
    log_message "INFO" "Testing Docker Compose on remote server..."
    if ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "cd $REMOTE_DIR && sudo docker-compose --version" >/dev/null 2>&1; then
        log_message "SUCCESS" "Docker Compose found on remote server"
    else
        log_message "ERROR" "Docker Compose not accessible on remote server"
        exit 1
    fi
}

# Function to collect all logs
collect_logs() {
    log_message "INFO" "Starting log collection..."
    echo ""
    
    local failed_commands=0
    local total_commands=8
    
    # 1. Complete Docker Compose logs
    execute_ssh_command \
        "Collecting complete Docker logs (last 2000 lines)" \
        "sudo docker-compose logs --tail 2000" \
        "$LOCAL_OUTPUT_DIR/complete-docker-logs-$TIMESTAMP.log" \
        1 $total_commands || ((failed_commands++))
    
    # 2. Backend service logs
    execute_ssh_command \
        "Collecting backend service logs" \
        "sudo docker-compose logs sms_backend" \
        "$LOCAL_OUTPUT_DIR/backend-logs.log" \
        2 $total_commands || ((failed_commands++))
    
    # 3. Frontend service logs
    execute_ssh_command \
        "Collecting frontend service logs" \
        "sudo docker-compose logs sms_frontend" \
        "$LOCAL_OUTPUT_DIR/frontend-logs.log" \
        3 $total_commands || ((failed_commands++))
    
    # 4. Nginx proxy logs
    execute_ssh_command \
        "Collecting nginx proxy logs" \
        "sudo docker-compose logs nginx" \
        "$LOCAL_OUTPUT_DIR/nginx-logs.log" \
        4 $total_commands || ((failed_commands++))
    
    # 5. Health check service logs
    execute_ssh_command \
        "Collecting health check service logs" \
        "sudo docker-compose logs health_check" \
        "$LOCAL_OUTPUT_DIR/health-check-logs.log" \
        5 $total_commands || ((failed_commands++))
    
    # 6. Services status
    execute_ssh_command \
        "Collecting services status" \
        "sudo docker-compose ps" \
        "$LOCAL_OUTPUT_DIR/services-status.log" \
        6 $total_commands || ((failed_commands++))
    
    # 7. Recent logs (last 4 hours)
    execute_ssh_command \
        "Collecting recent logs (last 4 hours)" \
        "sudo docker-compose logs --since 4h" \
        "$LOCAL_OUTPUT_DIR/recent-4h-logs.log" \
        7 $total_commands || ((failed_commands++))
    
    # 8. Docker system info
    execute_ssh_command \
        "Collecting Docker system info and stats" \
        "sudo docker system df && echo '=== CONTAINER STATS ===' && sudo docker stats --no-stream" \
        "$LOCAL_OUTPUT_DIR/docker-system-info.log" \
        8 $total_commands || ((failed_commands++))
    
    return $failed_commands
}

# Function to create summary
create_summary() {
    local failed_count="$1"
    local summary_file="$LOCAL_OUTPUT_DIR/collection-summary-$TIMESTAMP.txt"
    
    cat > "$summary_file" << EOF
EC2 Docker Logs Collection Summary
==================================
Collection Time: $(date)
SSH Target: $SSH_USER@$SSH_HOST
Remote Directory: $REMOTE_DIR
Local Output: $LOCAL_OUTPUT_DIR

Files Created:
EOF
    
    echo "" >> "$summary_file"
    ls -la "$LOCAL_OUTPUT_DIR"/*.log 2>/dev/null | while read line; do
        echo "  $line" >> "$summary_file"
    done 2>/dev/null || echo "  No log files found" >> "$summary_file"
    
    echo "" >> "$summary_file"
    echo "Collection Status: $((8 - failed_count))/8 commands successful" >> "$summary_file"
    
    if [[ $failed_count -gt 0 ]]; then
        echo "Failed Commands: $failed_count" >> "$summary_file"
    fi
    
    log_message "INFO" "Summary saved to: $summary_file"
}

# Function to show results
show_results() {
    local failed_count="$1"
    
    echo ""
    echo -e "${BOLD}${GREEN}========================================${NC}"
    echo -e "${BOLD}${GREEN}   Collection Complete!${NC}"
    echo -e "${BOLD}${GREEN}========================================${NC}"
    echo ""
    
    if [[ $failed_count -eq 0 ]]; then
        log_message "SUCCESS" "All 8 log collections completed successfully!"
    else
        log_message "WARNING" "$((8 - failed_count))/8 log collections completed ($failed_count failed)"
    fi
    
    echo ""
    echo -e "${BOLD}${PURPLE}Files created in: ${CYAN}$(realpath $LOCAL_OUTPUT_DIR)${NC}"
    echo -e "${PURPLE}===========================================${NC}"
    
    if ls "$LOCAL_OUTPUT_DIR"/*.log >/dev/null 2>&1; then
        ls -lah "$LOCAL_OUTPUT_DIR"/*.log | while read line; do
            echo -e "${CYAN}  $line${NC}"
        done
    else
        echo -e "${YELLOW}  No log files found${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}${PURPLE}Quick Commands:${NC}"
    echo -e "${PURPLE}===============${NC}"
    echo -e "${YELLOW}  View complete logs:    ${NC}less $LOCAL_OUTPUT_DIR/complete-docker-logs-$TIMESTAMP.log"
    echo -e "${YELLOW}  View backend logs:     ${NC}less $LOCAL_OUTPUT_DIR/backend-logs.log"
    echo -e "${YELLOW}  View services status:  ${NC}cat $LOCAL_OUTPUT_DIR/services-status.log"
    echo -e "${YELLOW}  View recent logs:      ${NC}less $LOCAL_OUTPUT_DIR/recent-4h-logs.log"
    echo ""
}

# Function to handle script interruption
cleanup() {
    echo ""
    log_message "WARNING" "Script interrupted by user"
    exit 1
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main execution
main() {
    check_prerequisites
    
    if collect_logs; then
        failed_count=$?
    else
        failed_count=$?
    fi
    
    create_summary $failed_count
    show_results $failed_count
    
    if [[ $failed_count -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Show usage if help requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo -e "${CYAN}Usage:${NC} $0"
    echo ""
    echo -e "${CYAN}Description:${NC}"
    echo "  Collects all Docker Compose logs from the SMS Seller Connect EC2 instance"
    echo "  and saves them to the local ec2-debug-output directory."
    echo ""
    echo -e "${CYAN}Configuration:${NC}"
    echo "  SSH Key:    $SSH_KEY"
    echo "  SSH Target: $SSH_USER@$SSH_HOST"
    echo "  Remote Dir: $REMOTE_DIR"
    echo "  Output Dir: $LOCAL_OUTPUT_DIR"
    echo ""
    echo -e "${CYAN}Files Created:${NC}"
    echo "  • complete-docker-logs-TIMESTAMP.log"
    echo "  • backend-logs.log"
    echo "  • frontend-logs.log"
    echo "  • nginx-logs.log"
    echo "  • health-check-logs.log"
    echo "  • services-status.log"
    echo "  • recent-4h-logs.log"
    echo "  • docker-system-info.log"
    echo "  • collection-summary-TIMESTAMP.txt"
    exit 0
fi

# Run main function
main "$@" 