import json
import boto3
import urllib.parse
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

s3_client = boto3.client('s3')
rekognition_client = boto3.client('rekognition')

def lambda_handler(event, context):
    try:
        # Extract bucket and key from the event
        message = json.loads(event['Records'][0]['Sns']['Message'])
        bucket = message['Records'][0]['s3']['bucket']['name']
        key = message['Records'][0]['s3']['object']['key']
        logger.info(f"Processing image: s3://{bucket}/{key}")

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

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Image processed successfully',
                'results': results,
                'result_key': result_key
            })
        }

    except Exception as e:
        logger.error(f"Error processing image: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
