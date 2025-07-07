#!/bin/bash

# Quick fix for backend container command issue
# This script restarts the backend container with the correct Docker-specific start script

set -e

echo "🔧 QUICK FIX: Backend Container Command Issue"
echo "============================================="
echo ""

# Define paths and variables
BACKEND_IMAGE="${BACKEND_IMAGE:-522814698925.dkr.ecr.us-east-1.amazonaws.com/sms-wholesaling-backend:latest}"
CONTAINER_NAME="sms_backend"

echo "🔍 Current container status:"
docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

echo ""
echo "🛑 Stopping current backend container..."
docker stop "$CONTAINER_NAME" 2>/dev/null || echo "Container not running"

echo "🗑️ Removing current backend container..."
docker rm "$CONTAINER_NAME" 2>/dev/null || echo "Container already removed"

echo ""
echo "🚀 Starting backend container with correct Docker script..."

# Get current environment variables
eval $(docker inspect nginx_proxy --format='{{range .Config.Env}}export {{.}}{{"\n"}}{{end}}' 2>/dev/null || echo "")

# Start backend container with Docker-specific script
docker run -d \
  --name "$CONTAINER_NAME" \
  --network="$(basename $(pwd))_app_network" \
  -p 8900:8900 \
  -e USE_POSTGRES=true \
  -e DB_HOST="${DB_HOST}" \
  -e DB_PORT="${DB_PORT:-5437}" \
  -e DB_NAME="${DB_NAME:-sms_blast}" \
  -e DB_USER="${DB_USER}" \
  -e DB_PASSWORD="${DB_PASSWORD}" \
  -e TWILIO_ACCOUNT_SID="${TWILIO_ACCOUNT_SID}" \
  -e TWILIO_AUTH_TOKEN="${TWILIO_AUTH_TOKEN}" \
  -e TWILIO_PHONE_NUMBER="${TWILIO_PHONE_NUMBER}" \
  -e OPENAI_API_KEY="${OPENAI_API_KEY}" \
  -e SECRET_KEY="${FLASK_SECRET_KEY}" \
  -e JWT_SECRET_KEY="${JWT_SECRET_KEY}" \
  -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
  -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
  -e AWS_REGION="${AWS_REGION}" \
  -e ENVIRONMENT=production \
  --restart unless-stopped \
  --health-cmd="wget --quiet --tries=1 --spider http://localhost:8900/health || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  "$BACKEND_IMAGE" \
  /bin/bash /app/start_backend_simple.sh

echo ""
echo "⏳ Waiting for backend container to start..."
sleep 5

echo ""
echo "🔍 Container status after restart:"
docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

echo ""
echo "📋 Container logs (last 20 lines):"
docker logs --tail 20 "$CONTAINER_NAME"

echo ""
echo "🏥 Health check:"
sleep 10
curl -f http://localhost:8900/health && echo "✅ Backend is healthy!" || echo "❌ Backend health check failed"

echo ""
echo "✅ Container restart completed!"
echo ""
echo "📝 Next steps:"
echo "1. Verify the backend is working: curl http://localhost:8900/health"
echo "2. Check container logs: docker logs $CONTAINER_NAME"
echo "3. If issues persist, run full redeploy: ./redeploy-application.sh" 