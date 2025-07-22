output "amazon_linux_2_id" {
  description = "AMI ID for Amazon Linux 2"
  value       = data.aws_ami.amazon_linux_2.id
}

output "amazon_linux_2023_id" {
  description = "AMI ID for Amazon Linux 2023"
  value       = data.aws_ami.amazon_linux_2023.id
}

output "ubuntu_20_04_id" {
  description = "AMI ID for Ubuntu 20.04"
  value       = data.aws_ami.ubuntu_20_04.id
}

output "ubuntu_22_04_id" {
  description = "AMI ID for Ubuntu 22.04"
  value       = data.aws_ami.ubuntu_22_04.id
}

# Convenience outputs for common use cases
output "latest_amazon_linux" {
  description = "Latest Amazon Linux AMI ID (AL2023)"
  value       = data.aws_ami.amazon_linux_2023.id
}

output "stable_amazon_linux" {
  description = "Stable Amazon Linux AMI ID (AL2)"
  value       = data.aws_ami.amazon_linux_2.id
}
