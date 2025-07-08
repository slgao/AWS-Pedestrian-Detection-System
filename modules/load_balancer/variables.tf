variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of public subnets for the ALB"
  type        = list(string)
}

variable "security_group_id" {
  description = "ID of the security group for the ALB"
  type        = string
}
