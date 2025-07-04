output "rds_endpoint" {
  description = "The connection endpoint"
  value       = split(":", aws_db_instance.main.endpoint)[0]
}
