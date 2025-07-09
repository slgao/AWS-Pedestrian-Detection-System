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

