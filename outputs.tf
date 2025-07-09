output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.subnet.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.subnet.private_subnet_ids
}

output "bastion_public_ip" {
  value = module.ec2_bastion.public_ip
}

output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = split(":", module.rds.rds_endpoint)[0]
}

output "alb_dns_name" {
  value = module.load_balancer.alb_dns_name
}

output "sns_topic_arn" {
  value = module.sns.sns_topic_arn
}

output "bucket_name" {
  value = module.s3.bucket_name
}

output "aws_iam_role_arn" {
  value = data.aws_iam_role.lambda_role.arn
}
