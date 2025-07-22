output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.alb_distribution.domain_name
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.alb_distribution.id
}

output "cloudfront_https_url" {
  description = "The HTTPS URL of the CloudFront distribution"
  value       = "https://${aws_cloudfront_distribution.alb_distribution.domain_name}"
}
