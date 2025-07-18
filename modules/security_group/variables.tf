variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "lambda_security_group_id" {
  description = "Lambda security group ID for RDS access"
  type        = string
  default     = ""
}
