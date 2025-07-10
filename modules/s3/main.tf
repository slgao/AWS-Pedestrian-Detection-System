# Use bucket name directly to avoid permission issues
resource "aws_s3_bucket_ownership_controls" "image_bucket" {
  bucket = var.bucket_name
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.bucket_name
  topic {
    topic_arn     = var.sns_topic_arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "Uploads/"
    filter_suffix = ".jpg"
  }
  depends_on = [aws_sns_topic_policy.s3_publish]
}

resource "aws_sns_topic_policy" "s3_publish" {
  arn = var.sns_topic_arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = var.sns_topic_arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.bucket_name}"
          }
        }
      }
    ]
  })
}
