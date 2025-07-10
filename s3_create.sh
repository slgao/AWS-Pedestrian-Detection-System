suffix="20256200"
aws s3 mb s3://my-app-image-bucket-"$suffix" --region us-west-2 
aws s3 mb s3://my-app-frontend-bucket-"$suffix" --region us-west-2
