#!/usr/bin/env python3

"""
Simple HTTP server for ALB health checks
Runs the health-check.sh script and returns appropriate HTTP responses
"""

import http.server
import socketserver
import subprocess
import json
import logging
import os
import signal
import sys
from datetime import datetime

# Configuration
PORT = 8888
HEALTH_CHECK_SCRIPT = "/app/sms-seller-connect/health-check.sh"

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] HealthCheckServer: %(message)s'
)
logger = logging.getLogger(__name__)

class HealthCheckHandler(http.server.BaseHTTPRequestHandler):
    
    def log_message(self, format, *args):
        """Override to use our logger"""
        logger.info(f"{self.address_string()} - {format % args}")
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/health-check':
            self.handle_health_check()
        elif self.path == '/status':
            self.handle_status()
        elif self.path == '/services':
            self.handle_services_detail()
        elif self.path.startswith('/logs/'):
            self.handle_logs()
        else:
            self.send_error(404, "Not Found")
    
    def handle_health_check(self):
        """Run the comprehensive health check"""
        try:
            # Run the health check script
            result = subprocess.run(
                ['/bin/bash', HEALTH_CHECK_SCRIPT],
                capture_output=True,
                text=True,
                timeout=15
            )
            
            timestamp = datetime.utcnow().isoformat() + 'Z'
            
            if result.returncode == 0:
                # All services healthy
                response_data = {
                    "status": "healthy",
                    "timestamp": timestamp,
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
                    "details": result.stdout.strip()
                }
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response_data, indent=2).encode())
                
                logger.info("✅ Health check passed - all services healthy")
                
            else:
                # One or more services unhealthy
                response_data = {
                    "status": "unhealthy",
                    "timestamp": timestamp,
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
                    "error": result.stderr.strip() if result.stderr else "Health check failed",
                    "details": result.stdout.strip()
                }
                
                self.send_response(503)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response_data, indent=2).encode())
                
                logger.warning("⚠️ Health check failed - one or more services unhealthy")
                
        except subprocess.TimeoutExpired:
            # Health check script timed out
            response_data = {
                "status": "unhealthy",
                "timestamp": datetime.utcnow().isoformat() + 'Z',
                "error": "Health check timed out after 15 seconds"
            }
            
            self.send_response(503)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response_data, indent=2).encode())
            
            logger.error("❌ Health check timed out")
            
        except Exception as e:
            # Unexpected error
            response_data = {
                "status": "unhealthy",
                "timestamp": datetime.utcnow().isoformat() + 'Z',
                "error": f"Health check server error: {str(e)}"
            }
            
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response_data, indent=2).encode())
            
            logger.error(f"❌ Health check server error: {str(e)}")
    
    def handle_status(self):
        """Simple status endpoint for the health check server itself"""
        response_data = {
            "service": "ALB Health Check Server",
            "status": "running",
            "timestamp": datetime.utcnow().isoformat() + 'Z',
            "port": PORT,
            "script": HEALTH_CHECK_SCRIPT
        }
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response_data, indent=2).encode())
    
    def handle_services_detail(self):
        """Detailed services status endpoint with live log activity"""
        try:
            # Get detailed service information
            services_info = {
                "timestamp": datetime.utcnow().isoformat() + 'Z',
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
                "background_services": {}
            }
            
            # Get live background service status with log activity
            try:
                background_services = self.get_live_background_services_status()
                services_info["background_services"] = background_services
            except Exception as e:
                logger.warning(f"Failed to get live background services status: {str(e)}")
                # Fallback to static info
                services_info["background_services"] = {
                    "scheduled-messages": {
                        "display_name": "📨 Scheduled Messages Service",
                        "description": "Sends scheduled SMS messages every 60 seconds",
                        "script": "scripts/scheduler_runner.py",
                        "log_file": "logs/scheduled_messages.log",
                        "status": "unknown",
                        "error": "Failed to get live status"
                    },
                    "ai-processor": {
                        "display_name": "🤖 AI Response Processor", 
                        "description": "Processes inbound messages for auto-responses using OpenAI",
                        "script": "scripts/ai_processor_runner.py",
                        "log_file": "logs/ai_processor.log",
                        "status": "unknown",
                        "error": "Failed to get live status"
                    }
                }
            
            # Try to get overall health status
            try:
                result = subprocess.run(
                    ['/bin/bash', HEALTH_CHECK_SCRIPT],
                    capture_output=True,
                    text=True,
                    timeout=15
                )
                services_info["overall_health"] = {
                    "status": "healthy" if result.returncode == 0 else "unhealthy",
                    "last_check": datetime.utcnow().isoformat() + 'Z',
                    "details": result.stdout.strip(),
                    "errors": result.stderr.strip() if result.stderr else None
                }
            except Exception as e:
                services_info["overall_health"] = {
                    "status": "unknown",
                    "last_check": datetime.utcnow().isoformat() + 'Z',
                    "error": f"Failed to get overall health: {str(e)}"
                }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(services_info, indent=2).encode())
            
        except Exception as e:
            error_response = {
                "error": f"Failed to get services detail: {str(e)}",
                "timestamp": datetime.utcnow().isoformat() + 'Z'
            }
            
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(error_response, indent=2).encode())
    
    def handle_logs(self):
        """Handle requests for live logs from background services"""
        # Extract service name from the path
        service_name = self.path.split('/logs/')[1]
        
        try:
            # Get live log for the specified service
            log_file = f"/app/logs/{service_name}.log"
            if not os.path.exists(log_file):
                self.send_error(404, "Log file not found")
                return
            
            with open(log_file, 'r') as f:
                log_content = f.read()
            
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(log_content.encode())
            
        except Exception as e:
            error_response = {
                "error": f"Failed to get log: {str(e)}",
                "timestamp": datetime.utcnow().isoformat() + 'Z'
            }
            
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(error_response, indent=2).encode())
    
    def get_live_background_services_status(self):
        """Get live status of background services with log activity"""
        services_status = {}
        
        # Define services to check
        services = {
            "scheduled-messages": {
                "display_name": "📨 Scheduled Messages Service",
                "description": "Sends scheduled SMS messages every 60 seconds",
                "script": "scripts/scheduler_runner.py",
                "log_file": "logs/scheduled_messages.log"
            },
            "ai-processor": {
                "display_name": "🤖 AI Response Processor",
                "description": "Processes inbound messages for auto-responses using OpenAI",
                "script": "scripts/ai_processor_runner.py", 
                "log_file": "logs/ai_processor.log"
            }
        }
        
        for service_name, service_info in services.items():
            try:
                # Get service status via docker exec
                status_cmd = f"""
                    pid_file="/app/logs/{service_name}.pid"
                    log_file="/app/{service_info['log_file']}"
                    
                    # Check process status
                    if [ -f "$pid_file" ]; then
                        pid=$(cat "$pid_file" 2>/dev/null)
                        if [ ! -z "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                            process_status="running"
                            process_pid="$pid"
                        else
                            process_status="stopped"
                            process_pid="$pid"
                        fi
                    else
                        process_status="not_started"
                        process_pid=""
                    fi
                    
                    # Check log status
                    if [ -f "$log_file" ]; then
                        log_size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")
                        log_modified=$(stat -c "%y" "$log_file" 2>/dev/null | cut -d'.' -f1 || echo "unknown")
                        recent_logs=$(tail -n 3 "$log_file" 2>/dev/null | tr '\\n' '|' | sed 's/|$//' || echo "")
                        log_exists="true"
                    else
                        log_size="0"
                        log_modified="unknown"
                        recent_logs=""
                        log_exists="false"
                    fi
                    
                    echo "PROCESS:$process_status|PID:$process_pid|LOG_EXISTS:$log_exists|LOG_SIZE:$log_size|LOG_MODIFIED:$log_modified|RECENT:$recent_logs"
                """
                
                result = subprocess.run(
                    ["docker", "exec", "sms_backend", "sh", "-c", status_cmd],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if result.returncode == 0:
                    # Parse the output
                    output = result.stdout.strip()
                    parts = {}
                    for part in output.split('|'):
                        if ':' in part:
                            key, value = part.split(':', 1)
                            parts[key] = value
                    
                    # Build service status
                    service_status = {
                        **service_info,
                        "status": parts.get("PROCESS", "unknown"),
                        "pid": parts.get("PID", ""),
                        "log_info": {
                            "exists": parts.get("LOG_EXISTS", "false") == "true",
                            "size_bytes": int(parts.get("LOG_SIZE", "0")),
                            "last_modified": parts.get("LOG_MODIFIED", "unknown"),
                            "recent_activity": []
                        }
                    }
                    
                    # Parse recent logs
                    recent_logs = parts.get("RECENT", "")
                    if recent_logs:
                        log_lines = [line.strip() for line in recent_logs.split('|') if line.strip()]
                        service_status["log_info"]["recent_activity"] = log_lines[-3:]  # Last 3 lines
                    
                    # Add human-readable status
                    if service_status["status"] == "running":
                        service_status["status_message"] = f"✅ Running (PID: {service_status['pid']})"
                        service_status["health"] = "healthy"
                    elif service_status["status"] == "stopped":
                        service_status["status_message"] = f"❌ Stopped (last PID: {service_status['pid']})"
                        service_status["health"] = "unhealthy"
                    else:
                        service_status["status_message"] = "⚠️ Not Started"
                        service_status["health"] = "unknown"
                    
                    # Add log summary
                    if service_status["log_info"]["exists"]:
                        log_size = service_status["log_info"]["size_bytes"]
                        if log_size > 0:
                            service_status["log_info"]["summary"] = f"📝 {log_size} bytes, modified: {service_status['log_info']['last_modified']}"
                        else:
                            service_status["log_info"]["summary"] = "📝 Empty log file"
                    else:
                        service_status["log_info"]["summary"] = "📝 No log file found"
                    
                else:
                    # Failed to get status
                    service_status = {
                        **service_info,
                        "status": "unknown",
                        "status_message": "❓ Status check failed",
                        "health": "unknown",
                        "error": result.stderr.strip() if result.stderr else "Failed to check service status",
                        "log_info": {
                            "exists": False,
                            "summary": "📝 Unable to check log file"
                        }
                    }
                    
            except Exception as e:
                # Exception occurred
                service_status = {
                    **service_info,
                    "status": "error",
                    "status_message": f"❌ Error: {str(e)}",
                    "health": "unknown",
                    "error": str(e),
                    "log_info": {
                        "exists": False,
                        "summary": "📝 Unable to check log file"
                    }
                }
            
            services_status[service_name] = service_status
        
        return services_status

def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    logger.info(f"Received signal {signum}, shutting down health check server...")
    sys.exit(0)

def main():
    """Main server function"""
    # Register signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Check if health check script exists
    if not os.path.exists(HEALTH_CHECK_SCRIPT):
        logger.error(f"Health check script not found: {HEALTH_CHECK_SCRIPT}")
        sys.exit(1)
    
    # Make sure script is executable
    os.chmod(HEALTH_CHECK_SCRIPT, 0o755)
    
    # Start the server
    try:
        with socketserver.TCPServer(("127.0.0.1", PORT), HealthCheckHandler) as httpd:
            logger.info(f"🚀 ALB Health Check Server started on port {PORT}")
            logger.info(f"📋 Using health check script: {HEALTH_CHECK_SCRIPT}")
            logger.info(f"🔗 Health check endpoint: http://127.0.0.1:{PORT}/health-check")
            logger.info(f"📊 Server status endpoint: http://127.0.0.1:{PORT}/status")
            logger.info(f"🔧 Detailed services endpoint: http://127.0.0.1:{PORT}/services")
            logger.info(f"📋 Live logs endpoint: http://127.0.0.1:{PORT}/logs/[service_name]")
            
            httpd.serve_forever()
            
    except OSError as e:
        if e.errno == 98:  # Address already in use
            logger.error(f"❌ Port {PORT} is already in use")
        else:
            logger.error(f"❌ Failed to start server: {str(e)}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"❌ Unexpected server error: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main() 