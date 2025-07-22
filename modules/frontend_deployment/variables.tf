# Variables for React Deployment Module

variable "gitlab_repo_url" {
  description = "GitLab repository URL for the React app"
  type        = string
  default     = "https://gitlab.com/your-username/your-react-app.git"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for storing assets"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "api_endpoint" {
  description = "API endpoint URL for the React app"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "use_amazon_linux_2023" {
  description = "Whether to use Amazon Linux 2023 (true) or Amazon Linux 2 (false)"
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

# RDS Database Variables
variable "rds_endpoint" {
  description = "RDS database endpoint"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "image_recognition"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
  default     = "react-frontend-instance"
}
