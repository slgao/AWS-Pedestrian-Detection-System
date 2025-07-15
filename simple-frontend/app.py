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

# Import database manager
try:
    from database import db_manager
    DATABASE_AVAILABLE = True
except ImportError as e:
    logging.warning(f"Database module not available: {e}")
    DATABASE_AVAILABLE = False

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
        # Check for both 'files' (multiple) and 'file' (single) form fields
        files = []
        if 'files' in request.files:
            files = request.files.getlist('files')
        elif 'file' in request.files:
            files = request.files.getlist('file')
        else:
            return jsonify({'error': 'No files provided'}), 400
        
        logger.info(f"Received {len(files)} files for upload")
        uploaded_files = []
        
        for file in files:
            if file.filename == '':
                continue
                
            # Generate unique filename
            file_extension = os.path.splitext(file.filename)[1]
            unique_filename = f"uploads/{uuid.uuid4()}{file_extension}"
            
            try:
                # Get file size
                file.seek(0, os.SEEK_END)
                file_size = file.tell()
                file.seek(0)
                
                # Upload to S3
                s3_client.upload_fileobj(
                    file,
                    S3_BUCKET,
                    unique_filename,
                    ExtraArgs={
                        'ContentType': file.content_type or 'application/octet-stream',
                        'Metadata': {
                            'original-name': file.filename,
                            'upload-time': datetime.utcnow().isoformat(),
                            'uploaded-by': 'image-recognition-system'
                        }
                    }
                )
                
                logger.info(f"Successfully uploaded to S3: {unique_filename}")
                
                # Store in database if available
                image_id = None
                if DATABASE_AVAILABLE:
                    try:
                        image_id = db_manager.create_image_record(
                            s3_key=unique_filename,
                            original_name=file.filename,
                            file_size=file_size
                        )
                        db_manager.log_processing_event(
                            image_id=image_id,
                            process_type='upload',
                            status='completed',
                            message=f'Uploaded to S3: {unique_filename}'
                        )
                        logger.info(f"Created database record with ID: {image_id}")
                    except Exception as db_error:
                        logger.error(f"Database error: {db_error}")
                        # Continue without database - don't fail the upload
                
                # Process with Rekognition (still synchronous for now)
                rekognition_result = process_with_rekognition(unique_filename)
                
                # Save Rekognition results to database if available
                if DATABASE_AVAILABLE and image_id:
                    try:
                        db_manager.save_detection_results(image_id, rekognition_result)
                        db_manager.update_processing_status(
                            image_id=image_id,
                            status='completed',
                            processed_at=datetime.utcnow()
                        )
                        logger.info(f"Saved detection results for image ID: {image_id}")
                    except Exception as db_error:
                        logger.error(f"Failed to save detection results: {db_error}")
                
                uploaded_files.append({
                    'fileName': unique_filename,
                    'originalName': file.filename,
                    's3Key': unique_filename,
                    'bucket': S3_BUCKET,
                    'status': 'uploaded',
                    'rekognition': rekognition_result,
                    'uploadTime': datetime.utcnow().isoformat(),
                    'processed_at': datetime.utcnow().isoformat(),
                    'imageId': image_id,
                    'fileSize': file_size
                })
                
                logger.info(f"Successfully uploaded and processed: {file.filename}")
                
            except ClientError as e:
                logger.error(f"S3 upload failed for {file.filename}: {e}")
                uploaded_files.append({
                    'fileName': file.filename,
                    'status': 'failed',
                    'error': str(e)
                })
            except Exception as e:
                logger.error(f"Processing failed for {file.filename}: {e}")
                uploaded_files.append({
                    'fileName': file.filename,
                    'status': 'failed',
                    'error': str(e)
                })
        
        return jsonify({
            'success': True,
            'files': uploaded_files,
            'bucket': S3_BUCKET,
            'database_enabled': DATABASE_AVAILABLE
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
        
        # Detect people/pedestrians specifically with detailed face attributes
        people_response = rekognition_client.detect_faces(
            Image={
                'S3Object': {
                    'Bucket': S3_BUCKET,
                    'Name': s3_key
                }
            },
            Attributes=['ALL']  # Request all face attributes including age, gender, emotions
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
                        'boundingBox': instance['BoundingBox'],
                        'type': 'person'
                    })
        
        # Extract face bounding boxes
        face_boxes = []
        for face in people_response.get('FaceDetails', []):
            if 'BoundingBox' in face:
                face_boxes.append({
                    'label': 'Face',
                    'confidence': face.get('Confidence', 95),
                    'boundingBox': face['BoundingBox'],
                    'type': 'face',
                    'ageRange': face.get('AgeRange', {}),
                    'gender': face.get('Gender', {}),
                    'emotions': face.get('Emotions', [])[:3],  # Top 3 emotions
                    'landmarks': face.get('Landmarks', [])
                })
        
        return {
            'labels': labels_response.get('Labels', [])[:10],  # Top 10 labels
            'peopleCount': people_count,
            'faceCount': len(face_boxes),
            'personLabels': person_labels,
            'boundingBoxes': bounding_boxes,
            'faceBoxes': face_boxes,
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

@app.route('/api/images', methods=['GET'])
def get_images():
    """Get list of uploaded images from database or S3 fallback"""
    try:
        logger.info("Fetching images...")
        
        # Try database first if available
        if DATABASE_AVAILABLE:
            try:
                logger.info("Fetching images from database")
                db_images = db_manager.get_all_images_with_detections()
                
                images = []
                for db_image in db_images:
                    # Generate presigned URL for the image
                    try:
                        image_url = s3_client.generate_presigned_url(
                            'get_object',
                            Params={'Bucket': S3_BUCKET, 'Key': db_image['s3_key']},
                            ExpiresIn=3600  # 1 hour
                        )
                    except Exception as url_error:
                        logger.warning(f"Could not generate URL for {db_image['s3_key']}: {url_error}")
                        continue
                    
                    # Convert database format to API format
                    rekognition_data = {
                        'labels': [
                            {'Name': label['label_name'], 'Confidence': float(label['confidence'])}
                            for label in db_image.get('labels', [])
                        ],
                        'boundingBoxes': [
                            {
                                'label': 'Person',
                                'confidence': float(person['confidence']),
                                'boundingBox': {
                                    'Left': float(person['bbox_left']),
                                    'Top': float(person['bbox_top']),
                                    'Width': float(person['bbox_width']),
                                    'Height': float(person['bbox_height'])
                                }
                            }
                            for person in db_image.get('person_detections', [])
                        ],
                        'faceBoxes': []
                    }
                    
                    # Process face detections
                    for face in db_image.get('face_detections', []):
                        face_data = {
                            'label': 'Face',
                            'confidence': float(face['confidence']),
                            'boundingBox': {
                                'Left': float(face['bbox_left']),
                                'Top': float(face['bbox_top']),
                                'Width': float(face['bbox_width']),
                                'Height': float(face['bbox_height'])
                            }
                        }
                        
                        # Add age range if available
                        if face.get('age_low') and face.get('age_high'):
                            face_data['ageRange'] = {
                                'Low': face['age_low'],
                                'High': face['age_high']
                            }
                        
                        # Add gender if available
                        if face.get('gender'):
                            face_data['gender'] = {
                                'Value': face['gender'],
                                'Confidence': float(face.get('gender_confidence', 0))
                            }
                        
                        # Add primary emotion if available
                        if face.get('primary_emotion'):
                            face_data['emotions'] = [{
                                'Type': face['primary_emotion'],
                                'Confidence': float(face.get('emotion_confidence', 0))
                            }]
                        
                        # Parse additional emotions if available
                        if face.get('emotions'):
                            emotions_str = face['emotions']
                            additional_emotions = []
                            for emotion_pair in emotions_str.split(','):
                                if ':' in emotion_pair:
                                    emotion_type, confidence = emotion_pair.split(':')
                                    additional_emotions.append({
                                        'Type': emotion_type,
                                        'Confidence': float(confidence)
                                    })
                            if additional_emotions:
                                face_data['emotions'] = additional_emotions
                        
                        rekognition_data['faceBoxes'].append(face_data)
                    
                    image_info = {
                        's3Key': db_image['s3_key'],
                        'fileName': db_image['s3_key'].split('/')[-1],
                        'originalName': db_image['original_name'],
                        'uploadTime': db_image['upload_time'].isoformat() if db_image['upload_time'] else None,
                        'size': db_image.get('file_size'),
                        'url': image_url,
                        'rekognition': rekognition_data,
                        'processing_status': db_image.get('processing_status'),
                        'processed_at': db_image['processed_at'].isoformat() if db_image.get('processed_at') else None,
                        'imageId': db_image['id']
                    }
                    
                    images.append(image_info)
                
                logger.info(f"Found {len(images)} images from database")
                
                return jsonify({
                    'success': True,
                    'images': images,
                    'count': len(images),
                    'bucket': S3_BUCKET,
                    'source': 'database'
                })
                
            except Exception as db_error:
                logger.error(f"Database error, falling back to S3: {db_error}")
                # Fall through to S3 fallback
        
        # Fallback to S3 scanning (original method)
        logger.info("Fetching images from S3 (fallback)")
        
        # List objects in S3 bucket
        response = s3_client.list_objects_v2(
            Bucket=S3_BUCKET,
            Prefix='uploads/'
        )
        
        images = []
        
        if 'Contents' in response:
            for obj in response['Contents']:
                s3_key = obj['Key']
                
                # Skip directories
                if s3_key.endswith('/'):
                    continue
                
                # Get object metadata
                try:
                    metadata_response = s3_client.head_object(Bucket=S3_BUCKET, Key=s3_key)
                    metadata = metadata_response.get('Metadata', {})
                    
                    # Generate presigned URL for the image
                    image_url = s3_client.generate_presigned_url(
                        'get_object',
                        Params={'Bucket': S3_BUCKET, 'Key': s3_key},
                        ExpiresIn=3600  # 1 hour
                    )
                    
                    # Try to get Rekognition results
                    rekognition_data = None
                    try:
                        rekognition_data = get_rekognition_results(s3_key)
                    except Exception as e:
                        logger.warning(f"Could not get Rekognition results for {s3_key}: {e}")
                    
                    image_info = {
                        's3Key': s3_key,
                        'fileName': s3_key.split('/')[-1],
                        'originalName': metadata.get('original-name', s3_key.split('/')[-1]),
                        'uploadTime': metadata.get('upload-time', obj['LastModified'].isoformat()),
                        'size': obj['Size'],
                        'url': image_url,
                        'rekognition': rekognition_data
                    }
                    
                    images.append(image_info)
                    
                except ClientError as e:
                    logger.error(f"Error getting metadata for {s3_key}: {e}")
                    continue
        
        logger.info(f"Found {len(images)} images from S3")
        
        return jsonify({
            'success': True,
            'images': images,
            'count': len(images),
            'bucket': S3_BUCKET,
            'source': 'S3'
        })
        
    except ClientError as e:
        logger.error(f"S3 error in get_images: {e}")
        return jsonify({'error': f'S3 error: {str(e)}', 'success': False}), 500
    except Exception as e:
        logger.error(f"Error in get_images: {e}")
        return jsonify({'error': str(e), 'success': False}), 500

def get_rekognition_results(s3_key):
    """Get Rekognition results for an image"""
    try:
        # Re-process with Rekognition to get current results
        return process_with_rekognition(s3_key)
    except Exception as e:
        logger.warning(f"Could not get Rekognition results for {s3_key}: {e}")
        return None

@app.route('/api/health')
def health_check():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'bucket': S3_BUCKET
    })

@app.route('/api/status/infrastructure')
def infrastructure_status():
    """Comprehensive infrastructure status check"""
    logger.info("Infrastructure status check requested")
    
    status = {
        'timestamp': datetime.utcnow().isoformat(),
        'components': {}
    }
    
    # Check S3 Bucket
    try:
        logger.info(f"Checking S3 bucket: {S3_BUCKET}")
        s3_client.head_bucket(Bucket=S3_BUCKET)
        # Try to list a few objects to verify access
        response = s3_client.list_objects_v2(Bucket=S3_BUCKET, MaxKeys=1)
        status['components']['s3'] = {
            'status': 'healthy',
            'message': f'Bucket {S3_BUCKET} accessible',
            'objects_count': response.get('KeyCount', 0)
        }
        logger.info("S3 check: healthy")
    except ClientError as e:
        logger.error(f"S3 check failed: {e}")
        status['components']['s3'] = {
            'status': 'unhealthy',
            'message': f'S3 Error: {str(e)}',
            'error_code': e.response['Error']['Code']
        }
    except Exception as e:
        logger.error(f"S3 connection error: {e}")
        status['components']['s3'] = {
            'status': 'unhealthy',
            'message': f'S3 Connection Error: {str(e)}'
        }
    
    # Check AWS Rekognition
    try:
        logger.info("Checking Rekognition service")
        # Test Rekognition by calling list_collections (lightweight operation)
        rekognition_client.list_collections(MaxResults=1)
        status['components']['rekognition'] = {
            'status': 'healthy',
            'message': 'Rekognition service accessible'
        }
        logger.info("Rekognition check: healthy")
    except ClientError as e:
        logger.error(f"Rekognition check failed: {e}")
        status['components']['rekognition'] = {
            'status': 'unhealthy',
            'message': f'Rekognition Error: {str(e)}',
            'error_code': e.response['Error']['Code']
        }
    except Exception as e:
        logger.error(f"Rekognition connection error: {e}")
        status['components']['rekognition'] = {
            'status': 'unhealthy',
            'message': f'Rekognition Connection Error: {str(e)}'
        }
    
    # Check Flask API (self)
    status['components']['api'] = {
        'status': 'healthy',
        'message': 'Flask API running',
        'config_loaded': bool(config),
        'bucket_configured': bool(S3_BUCKET)
    }
    logger.info("API check: healthy")
    
    # Check system resources
    try:
        import psutil
        logger.info("Checking system resources with psutil")
        cpu_percent = psutil.cpu_percent(interval=0.1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        status['components']['system'] = {
            'status': 'healthy' if cpu_percent < 80 and memory.percent < 80 else 'warning',
            'cpu_percent': round(cpu_percent, 1),
            'memory_percent': round(memory.percent, 1),
            'disk_percent': round(disk.percent, 1),
            'message': f'CPU: {cpu_percent:.1f}%, Memory: {memory.percent:.1f}%, Disk: {disk.percent:.1f}%'
        }
        logger.info(f"System check: {status['components']['system']['status']}")
    except ImportError:
        logger.warning("psutil not available")
        status['components']['system'] = {
            'status': 'unknown',
            'message': 'System monitoring not available'
        }
    except Exception as e:
        logger.error(f"System check error: {e}")
        status['components']['system'] = {
            'status': 'error',
            'message': f'System check error: {str(e)}'
        }
    
    # Overall health status
    component_statuses = [comp['status'] for comp in status['components'].values()]
    if 'unhealthy' in component_statuses or 'error' in component_statuses:
        status['overall'] = 'unhealthy'
    elif 'warning' in component_statuses:
        status['overall'] = 'warning'
    else:
        status['overall'] = 'healthy'
    
    logger.info(f"Overall status: {status['overall']}")
    logger.info(f"Returning status: {status}")
    
    return jsonify(status)

@app.route('/api/config')
def get_config():
    return jsonify(config)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
