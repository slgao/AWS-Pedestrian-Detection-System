output "public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "instance_id" {
  description = "Instance ID of the bastion host"
  value       = aws_instance.bastion.id
}

output "private_ip" {
  description = "Private IP address of the bastion host"
  value       = aws_instance.bastion.private_ip
}
