#!/usr/bin/env python3
import os
import json
import uuid
from datetime import datetime
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import boto3
from botocore.exceptions import ClientError
import logging

app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# AWS clients
s3_client = boto3.client('s3', region_name='us-west-2')
rekognition_client = boto3.client('rekognition', region_name='us-west-2')

# Load deployment configuration
def load_config():
    try:
        with open('/var/www/html/deployment-info.json', 'r') as f:
            return json.load(f)
    except Exception as e:
        logger.error(f"Failed to load config: {e}")
        return {
            's3Bucket': 'my-app-image-bucket-20256200',
            'region': 'us-west-2'
        }

config = load_config()
S3_BUCKET = config.get('s3Bucket', 'my-app-image-bucket-20256200')

@app.route('/api/upload', methods=['POST'])
def upload_images():
    try:
        if 'files' not in request.files:
            return jsonify({'error': 'No files provided'}), 400
        
        files = request.files.getlist('files')
        uploaded_files = []
        
        for file in files:
            if file.filename == '':
                continue
                
            # Generate unique filename
            file_extension = os.path.splitext(file.filename)[1]
            unique_filename = f"uploads/{uuid.uuid4()}{file_extension}"
            
            try:
                # Upload to S3
                s3_client.upload_fileobj(
                    file,
                    S3_BUCKET,
                    unique_filename,
                    ExtraArgs={
                        'ContentType': file.content_type,
                        'Metadata': {
                            'original-name': file.filename,
                            'upload-time': datetime.utcnow().isoformat(),
                            'uploaded-by': 'pedestrian-detection-system'
                        }
                    }
                )
                
                # Process with Rekognition
                rekognition_result = process_with_rekognition(unique_filename)
                
                uploaded_files.append({
                    'fileName': unique_filename,
                    'originalName': file.filename,
                    's3Key': unique_filename,
                    'bucket': S3_BUCKET,
                    'status': 'uploaded',
                    'rekognition': rekognition_result,
                    'uploadTime': datetime.utcnow().isoformat()
                })
                
                logger.info(f"Successfully uploaded and processed: {file.filename}")
                
            except ClientError as e:
                logger.error(f"S3 upload failed for {file.filename}: {e}")
                uploaded_files.append({
                    'fileName': file.filename,
                    'status': 'failed',
                    'error': str(e)
                })
        
        return jsonify({
            'success': True,
            'files': uploaded_files,
            'bucket': S3_BUCKET
        })
        
    except Exception as e:
        logger.error(f"Upload endpoint error: {e}")
        return jsonify({'error': str(e), 'success': False}), 500

def process_with_rekognition(s3_key):
    """Process image with AWS Rekognition for object detection"""
    try:
        # Detect labels (objects, scenes, activities)
        labels_response = rekognition_client.detect_labels(
            Image={
                'S3Object': {
                    'Bucket': S3_BUCKET,
                    'Name': s3_key
                }
            },
            MaxLabels=20,
            MinConfidence=70
        )
        
        # Detect people/pedestrians specifically
        people_response = rekognition_client.detect_faces(
            Image={
                'S3Object': {
                    'Bucket': S3_BUCKET,
                    'Name': s3_key
                }
            }
        )
        
        # Extract pedestrian-related information
        pedestrians = []
        people_count = len(people_response.get('FaceDetails', []))
        
        # Look for person-related labels
        person_labels = []
        for label in labels_response.get('Labels', []):
            if any(keyword in label['Name'].lower() for keyword in ['person', 'people', 'human', 'pedestrian', 'walking']):
                person_labels.append({
                    'name': label['Name'],
                    'confidence': label['Confidence'],
                    'instances': label.get('Instances', [])
                })
        
        # Extract bounding boxes for people
        bounding_boxes = []
        for label in person_labels:
            for instance in label.get('instances', []):
                if 'BoundingBox' in instance:
                    bounding_boxes.append({
                        'label': label['name'],
                        'confidence': instance.get('Confidence', label['confidence']),
                        'boundingBox': instance['BoundingBox']
                    })
        
        return {
            'labels': labels_response.get('Labels', [])[:10],  # Top 10 labels
            'peopleCount': people_count,
            'personLabels': person_labels,
            'boundingBoxes': bounding_boxes,
            'processedAt': datetime.utcnow().isoformat()
        }
        
    except ClientError as e:
        logger.error(f"Rekognition processing failed for {s3_key}: {e}")
        return {
            'error': str(e),
            'processedAt': datetime.utcnow().isoformat()
        }

@app.route('/api/image/<path:s3_key>')
def get_image_url(s3_key):
    """Generate presigned URL for S3 image"""
    try:
        url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': S3_BUCKET, 'Key': s3_key},
            ExpiresIn=3600  # 1 hour
        )
        return jsonify({'url': url, 'success': True})
    except ClientError as e:
        return jsonify({'error': str(e), 'success': False}), 500

@app.route('/api/health')
def health_check():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'bucket': S3_BUCKET
    })

@app.route('/api/config')
def get_config():
    return jsonify(config)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
