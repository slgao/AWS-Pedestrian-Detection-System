variable "subnet_ids" {
  description = "List of subnet IDs for RDS"
  type        = list(string)
}

variable "db_instance_identifier" {
  description = "Identifier for the RDS instance"
  type        = string
}

variable "db_engine" {
  description = "Database engine for RDS"
  type        = string
}

variable "db_engine_version" {
  description = "Database engine version for RDS"
  type        = string
}

variable "db_instance_class" {
  description = "Instance class for the RDS instance"
  type        = string
}

variable "db_name" {
  description = "Name of the database to create"
  type        = string
}

variable "db_username" {
  description = "Username for the database"
  type        = string
}

variable "db_password" {
  description = "Password for the database"
  type        = string
  sensitive   = true
}

variable "security_group_id" {
  description = "Security group ID for the instances"
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage for the RDS instance in GB"
  type        = number
}

variable "multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when deleting the RDS instance"
  type        = bool
}
