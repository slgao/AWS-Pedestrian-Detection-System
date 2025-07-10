#!/bin/bash
# This script uploads an image to an S3 bucket.
file_name="$1"			# with extension
suffix="20256200"

# Check if file_name was provided
if [ -z "$file_name" ]; then
    echo "Usage: $0 <file_name>.jpg"
    exit 1
fi

aws s3 cp assets/"$file_name" s3://my-app-image-bucket-"$suffix"/Uploads/"$file_name"
