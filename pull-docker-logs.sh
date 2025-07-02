#!/bin/bash

# ===============================================
# Pull Docker Compose Logs from SSH Machine
# ===============================================

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration - UPDATE THESE VALUES
SSH_HOST="your-server-ip-or-hostname"
SSH_USER="your-username"
SSH_KEY_PATH="$HOME/.ssh/your-key.pem"  # Optional: path to SSH key
REMOTE_APP_DIR="/app/sms-seller-connect"  # Path where docker-compose.yml is located
LOCAL_LOGS_DIR="./ssh-docker-logs"

echo -e "${BOLD}${BLUE}========================================${NC}"
echo -e "${BOLD}${BLUE}  Docker Compose Logs Puller${NC}"
echo -e "${BOLD}${BLUE}========================================${NC}"
echo ""

# Function to log with timestamp
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message"
}

# Create local logs directory
mkdir -p "$LOCAL_LOGS_DIR"

# Function to show usage
show_usage() {
    echo -e "${CYAN}Usage:${NC}"
    echo "  $0 [OPTIONS] [SERVICE_NAME]"
    echo ""
    echo -e "${CYAN}Options:${NC}"
    echo "  --live, -l        Stream logs in real-time (like -f)"
    echo "  --tail N          Show last N lines (default: 100)"
    echo "  --since TIME      Show logs since timestamp (e.g., '2h', '2023-01-01')"
    echo "  --all             Get logs from all services"
    echo "  --save            Save logs to local files"
    echo "  --help, -h        Show this help"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0 --live                    # Stream all logs live"
    echo "  $0 --save --all              # Save all service logs to files"
    echo "  $0 --tail 200 sms_backend    # Show last 200 lines from backend"
    echo "  $0 --since 1h sms_frontend   # Show frontend logs from last hour"
    echo ""
    echo -e "${YELLOW}Before running, update these variables in the script:${NC}"
    echo "  SSH_HOST, SSH_USER, SSH_KEY_PATH, REMOTE_APP_DIR"
}

# Parse command line arguments
LIVE_MODE=false
SAVE_MODE=false
ALL_SERVICES=false
TAIL_LINES=100
SINCE_TIME=""
SERVICE_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --live|-l)
            LIVE_MODE=true
            shift
            ;;
        --save)
            SAVE_MODE=true
            shift
            ;;
        --all)
            ALL_SERVICES=true
            shift
            ;;
        --tail)
            TAIL_LINES="$2"
            shift 2
            ;;
        --since)
            SINCE_TIME="$2"
            shift 2
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            if [[ -z "$SERVICE_NAME" ]]; then
                SERVICE_NAME="$1"
            fi
            shift
            ;;
    esac
done

# Validate configuration
if [[ "$SSH_HOST" == "your-server-ip-or-hostname" ]]; then
    echo -e "${RED}Error: Please update SSH_HOST in the script${NC}"
    echo -e "${YELLOW}Edit this script and set your actual server details${NC}"
    exit 1
fi

# Build SSH command
SSH_CMD="ssh"
if [[ -n "$SSH_KEY_PATH" && "$SSH_KEY_PATH" != *"your-key.pem" ]]; then
    SSH_CMD="$SSH_CMD -i $SSH_KEY_PATH"
fi
SSH_CMD="$SSH_CMD $SSH_USER@$SSH_HOST"

# Build docker-compose logs command
DOCKER_CMD="cd $REMOTE_APP_DIR && sudo docker-compose logs"

if [[ "$LIVE_MODE" == true ]]; then
    DOCKER_CMD="$DOCKER_CMD -f"
fi

if [[ -n "$TAIL_LINES" ]]; then
    DOCKER_CMD="$DOCKER_CMD --tail $TAIL_LINES"
fi

if [[ -n "$SINCE_TIME" ]]; then
    DOCKER_CMD="$DOCKER_CMD --since $SINCE_TIME"
fi

if [[ "$ALL_SERVICES" == false && -n "$SERVICE_NAME" ]]; then
    DOCKER_CMD="$DOCKER_CMD $SERVICE_NAME"
fi

# Function to get service list
get_services() {
    log_message "Getting list of services..."
    $SSH_CMD "cd $REMOTE_APP_DIR && sudo docker-compose ps --services" 2>/dev/null || echo "sms_backend sms_frontend nginx health_check"
}

# Function to save logs to files
save_logs_to_files() {
    log_message "Saving logs to local files..."
    
    local services
    if [[ "$ALL_SERVICES" == true ]]; then
        services=$(get_services)
    else
        services="$SERVICE_NAME"
    fi
    
    for service in $services; do
        if [[ -n "$service" ]]; then
            local log_file="$LOCAL_LOGS_DIR/${service}_$(date +%Y%m%d_%H%M%S).log"
            log_message "Saving $service logs to $log_file"
            
            local cmd="cd $REMOTE_APP_DIR && sudo docker-compose logs"
            if [[ -n "$TAIL_LINES" ]]; then
                cmd="$cmd --tail $TAIL_LINES"
            fi
            if [[ -n "$SINCE_TIME" ]]; then
                cmd="$cmd --since $SINCE_TIME"
            fi
            cmd="$cmd $service"
            
            $SSH_CMD "$cmd" > "$log_file" 2>&1
            echo -e "${GREEN}✓ Saved $service logs to $log_file${NC}"
        fi
    done
}

# Main execution
log_message "Connecting to $SSH_USER@$SSH_HOST..."

# Test SSH connection
if ! $SSH_CMD "echo 'SSH connection successful'" >/dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to SSH server${NC}"
    echo -e "${YELLOW}Check your SSH_HOST, SSH_USER, and SSH_KEY_PATH settings${NC}"
    exit 1
fi

echo -e "${GREEN}✓ SSH connection successful${NC}"

# Check if docker-compose exists on remote
if ! $SSH_CMD "cd $REMOTE_APP_DIR && sudo docker-compose --version" >/dev/null 2>&1; then
    echo -e "${RED}Error: docker-compose not found or no permission${NC}"
    echo -e "${YELLOW}Check REMOTE_APP_DIR path and sudo permissions${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker Compose found on remote server${NC}"

# Execute based on mode
if [[ "$SAVE_MODE" == true ]]; then
    save_logs_to_files
    echo -e "${BOLD}${GREEN}Logs saved to: $LOCAL_LOGS_DIR${NC}"
else
    log_message "Streaming logs from remote server..."
    echo -e "${CYAN}Command: $DOCKER_CMD${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    
    # Stream logs
    $SSH_CMD "$DOCKER_CMD"
fi
