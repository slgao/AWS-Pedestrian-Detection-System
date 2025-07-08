#!/bin/bash

# Configuration
KEY_NAME="labsuser"
KEY_FILE="./${KEY_NAME}.pem"
REGION="us-west-2"  # Change this as needed

# Check if key pair exists in AWS
echo "Checking if key pair '$KEY_NAME' exists in AWS..."
aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "Key pair '$KEY_NAME' already exists in AWS."
  echo "Deleting existing key pair to recreate..."
  aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$REGION"
fi

echo "Creating key pair '$KEY_NAME'..."
aws ec2 create-key-pair --key-name "$KEY_NAME" --region "$REGION" \
  --query 'KeyMaterial' --output text > "$KEY_FILE"

if [ $? -ne 0 ]; then
  echo "❌ Failed to create key pair."
  exit 1
fi

chmod 400 "$KEY_FILE"
echo "✅ Key pair '$KEY_NAME' created and saved to '$KEY_FILE'."

