# Lambda function using manually created package
# Run create_compatible_package.sh before terraform apply
resource "aws_lambda_function" "rekognition_function" {
  filename      = "${path.module}/lambda_function.zip"
  function_name = "rekognition-image-processor"
  role          = var.lambda_role_arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"
  timeout       = 300
  memory_size   = 512

  # Use file hash to detect changes in the zip file
  source_code_hash = filebase64sha256("${path.module}/lambda_function.zip")

  # VPC Configuration - Use private subnets with NAT Gateway for internet access
  vpc_config {
    subnet_ids         = var.private_subnet_ids # Back to private subnets
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      RDS_HOSTNAME   = var.rds_endpoint
      RDS_PORT       = "3306"
      RDS_DB_NAME    = var.db_name
      RDS_USERNAME   = var.db_username
      RDS_PASSWORD   = var.db_password
      S3_BUCKET_NAME = var.bucket_name
    }
  }

  tags = {
    Name        = "rekognition-image-processor"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Security Group for Lambda function
resource "aws_security_group" "lambda_sg" {
  name_prefix = "lambda-rekognition-sg"
  vpc_id      = var.vpc_id

  # Outbound rules
  egress {
    description = "HTTPS to internet (for Rekognition API)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP to internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "MySQL to RDS"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # Allow MySQL traffic to the entire VPC
  }

  tags = {
    Name = "lambda-rekognition-sg"
  }
}

# Lambda permission for SNS to invoke the function
resource "aws_lambda_permission" "sns_trigger" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rekognition_function.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_topic_arn
}

# SNS subscription to trigger Lambda
resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = var.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.rekognition_function.arn

  depends_on = [aws_lambda_permission.sns_trigger]
}

# CloudWatch Log Group for Lambda function
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/rekognition-image-processor"
  retention_in_days = 7

  tags = {
    Name        = "rekognition-lambda-logs"
    Environment = "production"
  }
}
