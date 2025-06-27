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