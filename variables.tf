variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_blocks" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
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

variable "db_instance_identifier" {
  description = "RDS instance identifier"
  type        = string
  default     = "mydb-instance"
}

variable "db_engine" {
  description = "RDS database engine"
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "RDS database engine version"
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage for RDS instance in GB"
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when deleting RDS instance"
  type        = bool
  default     = true
}

variable "db_name" {
  description = "RDS database name"
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "RDS database username"
  type        = string
  default     = "admin"
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
  description = "WordPress admin username"
  type        = string
  default     = "wpuser"
}

variable "wp_password" {
  description = "WordPress admin password"
  type        = string
  sensitive   = true
}

variable "lambda_role_name" {
  description = "Name of the existing IAM role for Lambda execution"
  type        = string
  default     = "LabRole" # Replace with your lab's role name
}

variable "s3_bucket_name" {
  description = "Name of the existing S3 bucket"
  type        = string
}

variable "frontend_bucket_name" {
  description = "Name of the S3 bucket for hosting the frontend application"
  type        = string
}
