variable "subnet_id" {
  description = "ID of the subnet"
  type        = string
}

variable "security_group_id" {
  description = "ID of the security group"
  type        = string
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  type        = string
}

variable "instance_type" {
  description = "Type of the EC2 instance"
  type        = string
  default     = "t3.micro"
}

variable "use_amazon_linux_2023" {
  description = "Whether to use Amazon Linux 2023 (true) or Amazon Linux 2 (false)"
  type        = bool
  default     = false # Default to AL2 for bastion since it uses amazon-linux-extras
}

variable "db_name" {
  description = "RDS database name for WordPress"
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "RDS database username"
  type        = string
}

variable "db_password" {
  description = "RDS database password"
  type        = string
  sensitive   = true
}

variable "wp_db_name" {
  description = "WordPress database name"
  type        = string
  default     = "wordpress"
}

variable "wp_username" {
  description = "RDS database username"
  type        = string
}

variable "wp_password" {
  description = "RDS database password"
  type        = string
  sensitive   = true
}

variable "rds_endpoint" {
  description = "RDS endpoint URL"
  type        = string
}
