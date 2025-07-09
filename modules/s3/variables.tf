variable "sns_topic_arn" {
  description = "ARN of the SNS topic for S3 event notifications"
  type        = string
}

variable "bucket_name" {
  description = "Name of the existing S3 bucket"
  type        = string
}
