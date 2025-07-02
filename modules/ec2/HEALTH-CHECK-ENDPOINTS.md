# SMS Seller Connect Health Check Endpoints

## Overview
The SMS Seller Connect application now includes comprehensive health monitoring for all services, including background processes.

## Available Endpoints

### 🏥 Main Health Check
**URL:** `http://localhost:8888/health-check`  
**Purpose:** Primary ALB health check endpoint  
**Returns:** Overall system health status

```json
{
  "status": "healthy",
  "timestamp": "2025-01-07T12:00:00.000Z",
  "containers": ["sms_backend", "sms_frontend", "nginx_proxy"],
  "background_services": [
    {
      "name": "scheduled-messages",
      "display_name": "📨 Scheduled Messages Service",
      "description": "Sends scheduled SMS messages every 60 seconds"
    },
    {
      "name": "ai-processor",
      "display_name": "🤖 AI Response Processor", 
      "description": "Processes inbound messages for auto-responses"
    }
  ],
  "details": "Health check output..."
}
```

### 📊 Server Status
**URL:** `http://localhost:8888/status`  
**Purpose:** Health check server status  
**Returns:** Information about the health check service itself

```json
{
  "service": "ALB Health Check Server",
  "status": "running",
  "timestamp": "2025-01-07T12:00:00.000Z",
  "port": 8888,
  "script": "/app/sms-seller-connect/health-check.sh"
}
```

### 🔧 Detailed Services Status
**URL:** `http://localhost:8888/services`  
**Purpose:** Comprehensive service information  
**Returns:** Detailed status of all containers and background services

```json
{
  "timestamp": "2025-01-07T12:00:00.000Z",
  "containers": {
    "sms_backend": {
      "name": "SMS Backend API",
      "port": 8900,
      "health_endpoint": "/health",
      "description": "FastAPI backend with authentication and SMS processing"
    },
    "sms_frontend": {
      "name": "SMS Frontend",
      "port": 8082,
      "description": "React frontend application"
    },
    "nginx_proxy": {
      "name": "Nginx Reverse Proxy", 
      "port": 80,
      "description": "Routes requests between frontend and backend"
    }
  },
  "background_services": {
    "scheduled-messages": {
      "display_name": "📨 Scheduled Messages Service",
      "description": "Sends scheduled SMS messages every 60 seconds",
      "script": "scripts/scheduler_runner.py",
      "log_file": "logs/scheduled_messages.log",
      "status": "running",
      "pid": "1234",
      "status_message": "✅ Running (PID: 1234)",
      "health": "healthy",
      "log_info": {
        "exists": true,
        "size_bytes": 2048,
        "last_modified": "2025-01-07 12:00:00",
        "recent_activity": [
          "2025-01-07 12:00:00 - INFO - Scheduled messages processed successfully",
          "2025-01-07 11:59:00 - INFO - Found 3 scheduled messages to send"
        ],
        "summary": "📝 2048 bytes, modified: 2025-01-07 12:00:00"
      }
    },
    "ai-processor": {
      "display_name": "🤖 AI Response Processor",
      "description": "Processes inbound messages for auto-responses using OpenAI", 
      "script": "scripts/ai_processor_runner.py",
      "log_file": "logs/ai_processor.log",
      "status": "running",
      "pid": "1235",
      "status_message": "✅ Running (PID: 1235)",
      "health": "healthy",
      "log_info": {
        "exists": true,
        "size_bytes": 4096,
        "last_modified": "2025-01-07 12:00:00",
        "recent_activity": [
          "2025-01-07 12:00:00 - INFO - AI inbound message processing completed successfully",
          "2025-01-07 11:58:00 - INFO - Found 2 inbound messages to process"
        ],
        "summary": "📝 4096 bytes, modified: 2025-01-07 12:00:00"
      }
    }
  },
  "overall_health": {
    "status": "healthy",
    "last_check": "2025-01-07T12:00:00.000Z",
    "details": "Live health check results..."
  }
}
```

### 📋 Live Log Viewer
**URL:** `http://localhost:8888/logs/{service_name}`  
**Purpose:** View live logs from background services  
**Returns:** Raw log content in text format

**Available logs:**
- `http://localhost:8888/logs/scheduled_messages` - Scheduled SMS messages log
- `http://localhost:8888/logs/ai_processor` - AI response processor log

**Example:**
```
2025-01-07 12:00:00 - INFO - Starting AI Response Processor for inbound messages...
2025-01-07 12:00:01 - INFO - Using response frequency: 60 seconds
2025-01-07 12:01:00 - INFO - AI inbound message processing completed successfully
2025-01-07 12:02:00 - INFO - Found 2 inbound messages to process
2025-01-07 12:02:01 - INFO - ✅ Successfully processed message 123
```

## Background Services Monitored

### 📨 Scheduled Messages Service
- **Script:** `scripts/scheduler_runner.py`
- **Function:** Sends scheduled SMS messages every 60 seconds
- **Log:** `logs/scheduled_messages.log`
- **PID File:** `logs/scheduled-messages.pid`

### 🤖 AI Response Processor
- **Script:** `scripts/ai_processor_runner.py`  
- **Function:** Processes inbound messages for auto-responses using OpenAI
- **Log:** `logs/ai_processor.log`
- **PID File:** `logs/ai-processor.pid`

## Health Check Logic

### Container Health
✅ **Healthy** - All containers (sms_backend, sms_frontend, nginx_proxy) are running  
❌ **Unhealthy** - One or more containers are not running

### Background Services Health
✅ **Running** - Process ID exists and process is active  
⚠️ **Warning** - PID file missing or process not responding  
❌ **Failed** - Process crashed or never started

### Overall Status
- **healthy** - Core containers are healthy (background services are non-critical for ALB)
- **unhealthy** - One or more core containers are failing

## Accessing Health Checks

### From ALB
The ALB will automatically call `/health-check` endpoint on port 8888

### From Browser/curl
```bash
# Main health check
curl http://your-domain.com:8888/health-check

# Server status  
curl http://your-domain.com:8888/status

# Detailed services
curl http://your-domain.com:8888/services
```

### From Inside Container
```bash
# Check all services
docker exec sms_backend /app/scripts/check_services.sh

# View live logs
docker exec sms_backend tail -f /app/logs/scheduled_messages.log
docker exec sms_backend tail -f /app/logs/ai_processor.log
```

## Troubleshooting

### Background Service Not Running
1. Check PID file: `ls -la /app/logs/*.pid`
2. Check logs: `tail -f /app/logs/[service].log`
3. Restart container to restart all services

### Health Check Failing
1. Check container status: `docker ps`
2. Check individual service endpoints
3. Review health check logs: `docker logs health_check_service`

## Log Files Location
- **Scheduled Messages:** `/app/logs/scheduled_messages.log`
- **AI Processor:** `/app/logs/ai_processor.log`
- **Health Check:** Docker container logs
- **Backend API:** Docker container logs 