output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.subnet.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.subnet.private_subnet_ids
}

output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = split(":", module.rds.rds_endpoint)[0]
}
