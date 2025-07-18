variable "sns_topic_arn" {
  description = "ARN of the SNS topic"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket for image storage"
  type        = string
}

variable "lambda_role_arn" {
  description = "ARN of the existing IAM role for Lambda execution"
  type        = string
}

# RDS Database Variables
variable "rds_endpoint" {
  description = "RDS database endpoint"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "image_recognition"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# VPC Variables for Lambda networking
variable "vpc_id" {
  description = "VPC ID where Lambda should run"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda (with NAT Gateway for internet access)"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

