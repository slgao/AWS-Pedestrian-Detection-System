#!/bin/bash
set -e

# Config
S3_BUCKET="${s3_bucket_name}"
LOG="/tmp/deploy.log"

# Install packages
sudo dnf update -y
sudo dnf install -y nginx git python3 python3-pip
sudo pip3 install flask flask-cors boto3

# Setup web directory
sudo mkdir -p /var/www/html
sudo chown ec2-user:ec2-user /var/www/html

# Try to clone repo, fallback to basic HTML
cd /tmp
if git clone ${gitlab_repo_url} repo && [ -d "repo" ]; then
    sudo cp -r repo/* /var/www/html/ 2>/dev/null || true
fi

# Create basic HTML if needed
if [ ! -f /var/www/html/index.html ]; then
    sudo tee /var/www/html/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html><head><title>Pedestrian Detection System</title>
<style>body{font-family:Arial;text-align:center;padding:50px;background:#667eea;color:white}
.container{max-width:800px;margin:0 auto;padding:40px;background:rgba(255,255,255,0.1);border-radius:20px}
h1{font-size:2.5rem;margin-bottom:20px}
.status{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:20px;margin:30px 0}
.status-item{background:rgba(255,255,255,0.2);padding:20px;border-radius:15px}
</style></head>
<body><div class="container">
<h1>🚶‍♂️ Pedestrian Detection System</h1>
<p>AWS 3-Tier Architecture - AI-Powered Computer Vision</p>
<div class="status">
<div class="status-item"><h3>🔄 Load Balancer</h3><span>✅ Active</span></div>
<div class="status-item"><h3>📈 Auto Scaling</h3><span>✅ Running</span></div>
<div class="status-item"><h3>🗄️ Database</h3><span>✅ Connected</span></div>
<div class="status-item"><h3>☁️ Storage</h3><span>✅ Ready</span></div>
</div>
<p>Instance: <span id="instanceId">Loading...</span> | AZ: <span id="az">Loading...</span></p>
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

# Basic nginx config
sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    server {
        listen 80;
        server_name _;
        root /var/www/html;
        index index.html;
        location /api/ {
            proxy_pass http://127.0.0.1:5000;
            proxy_set_header Host $host;
            client_max_body_size 50M;
        }
        location / { try_files $uri $uri/ /index.html; }
        location /health { return 200 "healthy\n"; add_header Content-Type text/plain; }
    }
}
EOF

# Setup Flask API - use from simple-frontend if available
if [ -f /var/www/html/app.py ]; then
    sudo cp /var/www/html/app.py /opt/app.py
    echo "Using Flask API from simple-frontend" >> $LOG
else
    # Create fallback Flask API with proper health endpoint
    sudo tee /opt/app.py > /dev/null << 'EOF'
#!/usr/bin/env python3
import os,json,uuid
from datetime import datetime
from flask import Flask,request,jsonify
from flask_cors import CORS
import boto3

app=Flask(__name__)
CORS(app)
s3=boto3.client('s3',region_name='us-west-2')
rek=boto3.client('rekognition',region_name='us-west-2')
BUCKET='my-app-image-bucket-20256200'

@app.route('/api/upload',methods=['POST'])
def upload():
    try:
        files=request.files.getlist('files')
        result=[]
        for f in files:
            if f.filename:
                key=f"uploads/{uuid.uuid4()}{os.path.splitext(f.filename)[1]}"
                s3.upload_fileobj(f,BUCKET,key)
                labels=rek.detect_labels(Image={'S3Object':{'Bucket':BUCKET,'Name':key}},MaxLabels=10,MinConfidence=70)
                result.append({'fileName':key,'originalName':f.filename,'s3Key':key,'status':'uploaded','rekognition':{'labels':labels.get('Labels',[])}})
        return jsonify({'success':True,'files':result})
    except Exception as e:
        return jsonify({'error':str(e),'success':False}),500

@app.route('/api/image/<path:key>')
def get_url(key):
    try:
        url=s3.generate_presigned_url('get_object',Params={'Bucket':BUCKET,'Key':key},ExpiresIn=3600)
        return jsonify({'url':url,'success':True})
    except Exception as e:
        return jsonify({'error':str(e),'success':False}),500

@app.route('/api/health')
def health():
    return jsonify({'status':'healthy-fallback-flask','timestamp':datetime.utcnow().isoformat(),'bucket':BUCKET})

@app.route('/api/config')
def config():
    return jsonify({'s3Bucket':BUCKET,'region':'us-west-2'})

if __name__=='__main__':
    app.run(host='0.0.0.0',port=5000,debug=False)
EOF
    echo "Using fallback Flask API" >> $LOG
fi

# Create systemd service
sudo tee /etc/systemd/system/flask-api.service > /dev/null << 'EOF'
[Unit]
Description=Flask API
After=network.target
[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt
ExecStart=/usr/bin/python3 /opt/app.py
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF

# Start services
sudo nginx -t && sudo systemctl enable nginx && sudo systemctl start nginx
sudo systemctl daemon-reload && sudo systemctl enable flask-api && sudo systemctl start flask-api

# Create deployment info - EC2 instance enforces IMDSv2 and won't accept the older IMDSv1 call.
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

sudo tee /var/www/html/deployment-info.json > /dev/null << EOF
{
    "deploymentTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "${environment}",
    "s3Bucket": "$S3_BUCKET",
    "apiEndpoint": "${api_endpoint}",
    "instanceId": "$INSTANCE_ID",
    "availabilityZone": "$AZ",
    "deploymentType": "pedestrian-detection-frontend",
    "projectName": "pedestrian-detection-system"
}
EOF

sudo chown -R nginx:nginx /var/www/html
rm -rf /tmp/repo
echo "Deployment completed at $(date)" >> $LOG
