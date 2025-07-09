import json
import boto3
import urllib.parse
import logging
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont
import os

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

s3_client = boto3.client('s3')
rekognition_client = boto3.client('rekognition')

def draw_bounding_box(image, box, label, confidence):
    """Draw bounding box and label on the image."""
    img_width, img_height = image.size
    left = img_width * box['Left']
    top = img_height * box['Top']
    width = img_width * box['Width']
    height = img_height * box['Height']
    
    draw = ImageDraw.Draw(image)
    # Draw rectangle
    draw.rectangle(
        [(left, top), (left + width, top + height)],
        outline='red',
        width=2
    )
    # Draw label
    try:
        font = ImageFont.truetype("arial.ttf", 20)
    except:
        font = ImageFont.load_default()
    text = f"{label} ({confidence:.2f}%)"
    text_bbox = draw.textbbox((left, top), text, font=font)
    draw.rectangle(text_bbox, fill='red')
    draw.text((left, top), text, fill='white', font=font)
    return image

def lambda_handler(event, context):
    try:
        # Extract bucket and key from the event
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'])
        logger.info(f"Processing image: s3://{bucket}/{key}")

        # Download image from S3
        response = s3_client.get_object(Bucket=bucket, Key=key)
        image_bytes = response['Body'].read()
        image = Image.open(BytesIO(image_bytes))

        # Call Rekognition DetectLabels
        response = rekognition_client.detect_labels(
            Image={'S3Object': {'Bucket': bucket, 'Name': key}},
            MaxLabels=10,
            MinConfidence=70
        )

        # Process detection results
        results = []
        for label in response['Labels']:
            label_data = {
                'Name': label['Name'],
                'Confidence': label['Confidence']
            }
            if 'Instances' in label:
                label_data['Instances'] = []
                for instance in label['Instances']:
                    if 'BoundingBox' in instance:
                        box = instance['BoundingBox']
                        label_data['Instances'].append({
                            'BoundingBox': {
                                'Width': box['Width'],
                                'Height': box['Height'],
                                'Left': box['Left'],
                                'Top': box['Top']
                            },
                            'Confidence': instance.get('Confidence', label['Confidence'])
                        })
                        # Draw bounding box on image
                        image = draw_bounding_box(
                            image,
                            box,
                            label['Name'],
                            instance.get('Confidence', label['Confidence'])
                        )
            results.append(label_data)

        # Log results
        logger.info(f"Detection results: {json.dumps(results, indent=2)}")

        # Save results to S3
        result_key = f"Results/{key.split('/')[-1]}.json"
        s3_client.put_object(
            Bucket=bucket,
            Key=result_key,
            Body=json.dumps(results, indent=2),
            ContentType='application/json'
        )
        logger.info(f"Saved results to s3://{bucket}/{result_key}")

        # Save annotated image to S3
        annotated_key = f"Annotated/{key.split('/')[-1]}"
        output_buffer = BytesIO()
        image.save(output_buffer, format='JPEG')
        s3_client.put_object(
            Bucket=bucket,
            Key=annotated_key,
            Body=output_buffer.getvalue(),
            ContentType='image/jpeg'
        )
        logger.info(f"Saved annotated image to s3://{bucket}/{annotated_key}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Image processed successfully',
                'results': results,
                'result_key': result_key,
                'annotated_key': annotated_key
            })
        }

    except Exception as e:
        logger.error(f"Error processing image: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
