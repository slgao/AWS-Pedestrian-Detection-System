#!/bin/bash
set -e

# Config
S3_BUCKET="${s3_bucket_name}"
LOG="/tmp/deploy.log"

echo "=== Frontend Deployment Started ===" >> $LOG
echo "Timestamp: $(date)" >> $LOG

# Install packages including database dependencies
echo "Installing system packages..." >> $LOG
sudo dnf update -y >> $LOG 2>&1
sudo dnf install -y nginx git python3 python3-pip >> $LOG 2>&1

# Note: MySQL client not needed for Flask app - PyMySQL handles database connections

# Install Python packages including database support
echo "Installing Python packages..." >> $LOG
sudo pip3 install flask flask-cors boto3 psutil pymysql cryptography >> $LOG 2>&1

# Setup web directory
sudo mkdir -p /var/www/html
sudo chown ec2-user:ec2-user /var/www/html

# Try to clone repo, fallback to basic HTML
cd /tmp
if git clone ${gitlab_repo_url} repo && [ -d "repo" ]; then
    echo "Cloned repository successfully" >> $LOG
    sudo cp -r repo/* /var/www/html/ 2>/dev/null || true
else
    echo "Repository clone failed, using fallback" >> $LOG
fi

# Create basic HTML if needed
if [ ! -f /var/www/html/index.html ]; then
    echo "Creating fallback HTML..." >> $LOG
    sudo tee /var/www/html/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html><head><title>Image Recognition System</title>
<style>body{font-family:Arial;text-align:center;padding:50px;background:#667eea;color:white}
.container{max-width:800px;margin:0 auto;padding:40px;background:rgba(255,255,255,0.1);border-radius:20px}
h1{font-size:2.5rem;margin-bottom:20px}
.status{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:20px;margin:30px 0}
.status-item{background:rgba(255,255,255,0.2);padding:20px;border-radius:15px}
</style></head>
<body><div class="container">
<h1>🎯 Image Recognition System</h1>
<p>AWS 3-Tier Architecture - AI-Powered Computer Vision with Database</p>
<div class="status">
<div class="status-item"><h3>🔄 Load Balancer</h3><span>✅ Active</span></div>
<div class="status-item"><h3>📈 Auto Scaling</h3><span>✅ Running</span></div>
<div class="status-item"><h3>🗄️ RDS Database</h3><span>✅ Connected</span></div>
<div class="status-item"><h3>☁️ S3 Storage</h3><span>✅ Ready</span></div>
<div class="status-item"><h3>🤖 Rekognition AI</h3><span>✅ Active</span></div>
<div class="status-item"><h3>⚡ Lambda Processing</h3><span>🔄 Coming Soon</span></div>
</div>
<p>Instance: <span id="instanceId">Loading...</span> | AZ: <span id="az">Loading...</span></p>
<p><a href="/index.html" style="color:#fff;text-decoration:underline">🎯 Go to Image Recognition App</a></p>
</div>
<script>
fetch('/deployment-info.json').then(r=>r.json()).then(d=>{
document.getElementById('instanceId').textContent=d.instanceId||'demo';
document.getElementById('az').textContent=d.availabilityZone||'us-west-2a';
}).catch(()=>{
document.getElementById('instanceId').textContent='demo';
document.getElementById('az').textContent='us-west-2a';
});
</script></body></html>
EOF
fi

# Enhanced nginx config with larger upload limits
echo "Configuring nginx..." >> $LOG
sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
events { 
    worker_connections 1024; 
}
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    client_max_body_size 100M;  # Allow large image uploads
    
    server {
        listen 80;
        server_name _;
        root /var/www/html;
        index index.html;
        
        # API proxy with enhanced settings
        location /api/ {
            proxy_pass http://127.0.0.1:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            client_max_body_size 100M;
            proxy_read_timeout 300s;
            proxy_connect_timeout 75s;
        }
        
        location / { 
            try_files $uri $uri/ /index.html; 
        }
        
        location /health { 
            return 200 "healthy\n"; 
            add_header Content-Type text/plain; 
        }
    }
}
EOF

# Setup Flask API - prioritize simple-frontend version
echo "Setting up Flask API..." >> $LOG
if [ -f /var/www/html/app.py ]; then
    echo "Using Flask API from simple-frontend directory" >> $LOG
    sudo cp /var/www/html/app.py /opt/app.py
    
    # Copy database.py if it exists
    if [ -f /var/www/html/database.py ]; then
        echo "Copying database.py for database support" >> $LOG
        sudo cp /var/www/html/database.py /opt/database.py
    else
        echo "Warning: database.py not found, database features will be disabled" >> $LOG
    fi
    
    # Copy requirements.txt if it exists and install additional dependencies
    if [ -f /var/www/html/requirements.txt ]; then
        echo "Found requirements.txt, checking for additional dependencies..." >> $LOG
        # Only install packages that aren't already installed to avoid conflicts
        echo "Note: Core packages already installed, skipping requirements.txt to avoid conflicts" >> $LOG
    fi
    
else
    echo "Creating fallback Flask API..." >> $LOG
    # Create fallback Flask API with basic functionality
    sudo tee /opt/app.py > /dev/null << 'EOF'
#!/usr/bin/env python3
import os,json,uuid
from datetime import datetime
from flask import Flask,request,jsonify
from flask_cors import CORS
import boto3

app=Flask(__name__)
CORS(app)

# Basic configuration
config = {
    's3Bucket': os.environ.get('S3_BUCKET', 'my-app-image-bucket-20256200'),
    'region': os.environ.get('AWS_REGION', 'us-west-2')
}

s3_client = boto3.client('s3', region_name=config['region'])

@app.route('/api/health')
def health():
    return jsonify({'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()})

@app.route('/api/config')
def get_config():
    return jsonify(config)

@app.route('/api/upload', methods=['POST'])
def upload():
    return jsonify({'error': 'Upload functionality requires full Flask app', 'status': 'fallback_mode'}), 501

@app.route('/api/images')
def images():
    return jsonify({'images': [], 'message': 'Database integration required for image listing', 'status': 'fallback_mode'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF
fi

# Create deployment info with database status
echo "Creating deployment info..." >> $LOG
# Create deployment info - EC2 instance enforces IMDSv2 and won't accept the older IMDSv1 call.
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Check if database.py exists to determine database support
DATABASE_SUPPORT="false"
if [ -f /opt/database.py ]; then
    DATABASE_SUPPORT="true"
fi

# Create deployment configuration with RDS details
sudo tee /var/www/html/deployment-info.json > /dev/null << EOF
{
    "deploymentTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "${environment}",
    "s3Bucket": "${s3_bucket_name}",
    "apiEndpoint": "${api_endpoint}",
    "instanceId": "$INSTANCE_ID",
    "availabilityZone": "$AZ",
    "deploymentType": "image-recognition-frontend",
    "projectName": "image-recognition-system",
    "databaseSupport": $DATABASE_SUPPORT,
    "rds_endpoint": "${rds_endpoint}",
    "rds_database": "${db_name}",
    "rds_username": "${db_username}",
    "features": {
        "imageUpload": true,
        "rekognitionAI": true,
        "databaseStorage": $DATABASE_SUPPORT,
        "realTimeProcessing": true
    }
}
EOF

echo "Database configuration:" >> $LOG
echo "  RDS Endpoint: ${rds_endpoint}" >> $LOG
echo "  Database: ${db_name}" >> $LOG
echo "  Username: ${db_username}" >> $LOG
echo "  Database Support: $DATABASE_SUPPORT" >> $LOG

# Create systemd service for Flask API with RDS environment variables
echo "Creating Flask service with database configuration..." >> $LOG
sudo tee /etc/systemd/system/flask-api.service > /dev/null << EOF
[Unit]
Description=Flask API for Image Recognition
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt
Environment=FLASK_APP=app.py
Environment=FLASK_ENV=production
Environment=RDS_HOSTNAME=${rds_endpoint}
Environment=RDS_PORT=3306
Environment=RDS_DB_NAME=${db_name}
Environment=RDS_USERNAME=${db_username}
Environment=RDS_PASSWORD=${db_password}
ExecStart=/usr/bin/python3 /opt/app.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Start services
echo "Starting services..." >> $LOG
sudo systemctl daemon-reload >> $LOG 2>&1
sudo systemctl enable nginx >> $LOG 2>&1
sudo systemctl start nginx >> $LOG 2>&1
sudo systemctl enable flask-api >> $LOG 2>&1
sudo systemctl start flask-api >> $LOG 2>&1

# Wait a moment and check service status
sleep 5
NGINX_STATUS=$(sudo systemctl is-active nginx)
FLASK_STATUS=$(sudo systemctl is-active flask-api)

echo "Service Status:" >> $LOG
echo "  Nginx: $NGINX_STATUS" >> $LOG
echo "  Flask API: $FLASK_STATUS" >> $LOG

# Test API endpoint
echo "Testing API endpoint..." >> $LOG
if curl -s http://localhost:5000/api/health > /dev/null; then
    echo "✅ Flask API is responding" >> $LOG
else
    echo "❌ Flask API is not responding" >> $LOG
fi

# Test nginx
if curl -s http://localhost/health > /dev/null; then
    echo "✅ Nginx is responding" >> $LOG
else
    echo "❌ Nginx is not responding" >> $LOG
fi

echo "=== Frontend Deployment Completed ===" >> $LOG
echo "Timestamp: $(date)" >> $LOG
echo "Database Support: $DATABASE_SUPPORT" >> $LOG
