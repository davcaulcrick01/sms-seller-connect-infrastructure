#!/bin/bash

# Quick SSH Docker Logs - One-liner commands
# Update these variables first:

SSH_HOST="your-server-ip"
SSH_USER="your-username" 
SSH_KEY="~/.ssh/your-key.pem"  # Optional
REMOTE_DIR="/app/sms-seller-connect"

echo "=== Quick SSH Docker Logs Commands ==="
echo ""
echo "1. UPDATE VARIABLES ABOVE FIRST!"
echo ""
echo "2. Choose your command:"
echo ""
echo "# Stream ALL logs live:"
echo "ssh -i $SSH_KEY $SSH_USER@$SSH_HOST 'cd $REMOTE_DIR && sudo docker-compose logs -f'"
echo ""
echo "# Stream specific service (e.g., backend):"
echo "ssh -i $SSH_KEY $SSH_USER@$SSH_HOST 'cd $REMOTE_DIR && sudo docker-compose logs -f sms_backend'"
echo ""
echo "# Get last 100 lines and save to file:"
echo "ssh -i $SSH_KEY $SSH_USER@$SSH_HOST 'cd $REMOTE_DIR && sudo docker-compose logs --tail 100' > docker-logs-$(date +%Y%m%d_%H%M%S).log"
echo ""
echo "# Get logs from last hour:"
echo "ssh -i $SSH_KEY $SSH_USER@$SSH_HOST 'cd $REMOTE_DIR && sudo docker-compose logs --since 1h'"
echo ""
echo "# Available services to check:"
echo "ssh -i $SSH_KEY $SSH_USER@$SSH_HOST 'cd $REMOTE_DIR && sudo docker-compose ps'"
echo ""
