import json
import boto3
import pymysql
import os
import logging
from datetime import datetime
from urllib.parse import unquote_plus

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
rekognition = boto3.client('rekognition')
s3 = boto3.client('s3')

# Database configuration from environment variables
DB_CONFIG = {
    'host': os.environ.get('RDS_HOSTNAME'),
    'port': int(os.environ.get('RDS_PORT', 3306)),
    'database': os.environ.get('RDS_DB_NAME', 'image_recognition'),
    'user': os.environ.get('RDS_USERNAME', 'admin'),  # Changed from 'username' to 'user'
    'password': os.environ.get('RDS_PASSWORD'),
    'charset': 'utf8mb4'
}

def lambda_handler(event, context):
    """
    Lambda function triggered by SNS when images are uploaded to S3
    Processes images with Rekognition and stores results in RDS
    """
    logger.info(f"Lambda triggered with event: {json.dumps(event)}")
    
    try:
        # Parse SNS message
        for record in event['Records']:
            if record['EventSource'] == 'aws:sns':
                # Parse S3 event from SNS message
                sns_message = json.loads(record['Sns']['Message'])
                
                for s3_record in sns_message['Records']:
                    if s3_record['eventName'].startswith('ObjectCreated'):
                        # Extract S3 details
                        bucket_name = s3_record['s3']['bucket']['name']
                        s3_key = unquote_plus(s3_record['s3']['object']['key'])
                        
                        logger.info(f"Processing image: {s3_key} from bucket: {bucket_name}")
                        
                        # Process the image
                        process_image(bucket_name, s3_key)
        
        return {
            'statusCode': 200,
            'body': json.dumps('Successfully processed images')
        }
        
    except Exception as e:
        logger.error(f"Error processing Lambda event: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def process_image(bucket_name, s3_key):
    """Process a single image with Rekognition and store results"""
    try:
        logger.info(f"Starting Rekognition processing for {s3_key}")
        
        # Get image metadata from S3
        s3_response = s3.head_object(Bucket=bucket_name, Key=s3_key)
        file_size = s3_response['ContentLength']
        original_name = s3_response.get('Metadata', {}).get('original-name', s3_key.split('/')[-1])
        upload_time = s3_response.get('Metadata', {}).get('upload-time')
        
        # Find or create image record in database
        image_id = get_or_create_image_record(s3_key, original_name, file_size, upload_time)
        
        if not image_id:
            logger.error(f"Failed to get/create image record for {s3_key}")
            return
        
        # Update processing status
        update_processing_status(image_id, 'processing', 'Lambda processing started')
        
        # Process with Rekognition
        rekognition_results = perform_rekognition_analysis(bucket_name, s3_key)
        
        # Save results to database
        save_rekognition_results(image_id, rekognition_results)
        
        # Update final status
        update_processing_status(image_id, 'completed', 'Processing completed successfully', datetime.utcnow())
        
        logger.info(f"Successfully processed {s3_key}")
        
    except Exception as e:
        logger.error(f"Error processing image {s3_key}: {str(e)}")
        if 'image_id' in locals():
            update_processing_status(image_id, 'failed', f'Processing failed: {str(e)}')

def perform_rekognition_analysis(bucket_name, s3_key):
    """Perform comprehensive Rekognition analysis"""
    results = {}
    
    try:
        # Detect labels
        logger.info("Detecting labels...")
        labels_response = rekognition.detect_labels(
            Image={'S3Object': {'Bucket': bucket_name, 'Name': s3_key}},
            MaxLabels=20,
            MinConfidence=70
        )
        results['labels'] = labels_response.get('Labels', [])
        
        # Detect faces
        logger.info("Detecting faces...")
        faces_response = rekognition.detect_faces(
            Image={'S3Object': {'Bucket': bucket_name, 'Name': s3_key}},
            Attributes=['ALL']
        )
        results['faces'] = faces_response.get('FaceDetails', [])
        
        # Extract person bounding boxes from labels
        person_boxes = []
        for label in results['labels']:
            if label['Name'].lower() == 'person':
                for instance in label.get('Instances', []):
                    if 'BoundingBox' in instance:
                        person_boxes.append({
                            'confidence': instance['Confidence'],
                            'boundingBox': instance['BoundingBox']
                        })
        results['person_detections'] = person_boxes
        
        logger.info(f"Rekognition analysis complete: {len(results['labels'])} labels, {len(results['faces'])} faces, {len(person_boxes)} people")
        
        return results
        
    except Exception as e:
        logger.error(f"Rekognition analysis failed: {str(e)}")
        raise

def get_database_connection():
    """Create database connection"""
    try:
        connection = pymysql.connect(**DB_CONFIG)
        return connection
    except Exception as e:
        logger.error(f"Database connection failed: {str(e)}")
        raise

def get_or_create_image_record(s3_key, original_name, file_size, upload_time):
    """Get existing image record or create new one"""
    connection = None
    try:
        connection = get_database_connection()
        
        with connection.cursor() as cursor:
            # Check if image already exists
            cursor.execute(
                "SELECT id FROM images WHERE s3_key = %s",
                (s3_key,)
            )
            result = cursor.fetchone()
            
            if result:
                logger.info(f"Found existing image record: {result[0]}")
                return result[0]
            
            # Create new image record
            cursor.execute("""
                INSERT INTO images (s3_key, original_name, file_size, upload_time, processing_status)
                VALUES (%s, %s, %s, %s, %s)
            """, (
                s3_key,
                original_name,
                file_size,
                upload_time or datetime.utcnow(),
                'pending'
            ))
            
            image_id = cursor.lastrowid
            connection.commit()
            
            logger.info(f"Created new image record: {image_id}")
            return image_id
            
    except Exception as e:
        logger.error(f"Database error in get_or_create_image_record: {str(e)}")
        if connection:
            connection.rollback()
        raise
    finally:
        if connection:
            connection.close()

def update_processing_status(image_id, status, message, processed_at=None):
    """Update image processing status"""
    connection = None
    try:
        connection = get_database_connection()
        
        with connection.cursor() as cursor:
            if processed_at:
                cursor.execute("""
                    UPDATE images 
                    SET processing_status = %s, processed_at = %s
                    WHERE id = %s
                """, (status, processed_at, image_id))
            else:
                cursor.execute("""
                    UPDATE images 
                    SET processing_status = %s
                    WHERE id = %s
                """, (status, image_id))
            
            # Log processing event
            cursor.execute("""
                INSERT INTO processing_logs (image_id, process_type, status, message, created_at)
                VALUES (%s, %s, %s, %s, %s)
            """, (image_id, 'rekognition', status, message, datetime.utcnow()))
            
            connection.commit()
            
    except Exception as e:
        logger.error(f"Error updating processing status: {str(e)}")
        if connection:
            connection.rollback()
    finally:
        if connection:
            connection.close()

def save_rekognition_results(image_id, results):
    """Save Rekognition results to database"""
    connection = None
    try:
        connection = get_database_connection()
        
        with connection.cursor() as cursor:
            # Save labels
            for label in results.get('labels', []):
                cursor.execute("""
                    INSERT INTO detection_labels (image_id, label_name, confidence)
                    VALUES (%s, %s, %s)
                """, (image_id, label['Name'], label['Confidence']))
            
            # Save person detections
            for person in results.get('person_detections', []):
                bbox = person['boundingBox']
                cursor.execute("""
                    INSERT INTO person_detections 
                    (image_id, confidence, bbox_left, bbox_top, bbox_width, bbox_height)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """, (
                    image_id,
                    person['confidence'],
                    bbox['Left'],
                    bbox['Top'],
                    bbox['Width'],
                    bbox['Height']
                ))
            
            # Save face detections
            for face in results.get('faces', []):
                bbox = face['BoundingBox']
                age_range = face.get('AgeRange', {})
                gender = face.get('Gender', {})
                emotions = face.get('Emotions', [])
                
                # Insert face detection
                cursor.execute("""
                    INSERT INTO face_detections 
                    (image_id, confidence, bbox_left, bbox_top, bbox_width, bbox_height,
                     age_low, age_high, gender, gender_confidence, primary_emotion, emotion_confidence)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """, (
                    image_id,
                    face.get('Confidence', 0),
                    bbox['Left'],
                    bbox['Top'],
                    bbox['Width'],
                    bbox['Height'],
                    age_range.get('Low'),
                    age_range.get('High'),
                    gender.get('Value'),
                    gender.get('Confidence'),
                    emotions[0]['Type'] if emotions else None,
                    emotions[0]['Confidence'] if emotions else None
                ))
                
                face_id = cursor.lastrowid
                
                # Save all emotions
                for emotion in emotions:
                    cursor.execute("""
                        INSERT INTO face_emotions (face_detection_id, emotion_type, confidence)
                        VALUES (%s, %s, %s)
                    """, (face_id, emotion['Type'], emotion['Confidence']))
            
            connection.commit()
            logger.info(f"Saved Rekognition results for image {image_id}")
            
    except Exception as e:
        logger.error(f"Error saving Rekognition results: {str(e)}")
        if connection:
            connection.rollback()
        raise
    finally:
        if connection:
            connection.close()
