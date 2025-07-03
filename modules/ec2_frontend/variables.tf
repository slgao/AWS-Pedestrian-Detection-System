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

variable "ami" {
  description = "AMI ID to use for the frontend instance"
  type        = string
}

variable "user_data" {
  description = "User data script for the frontend EC2"
  type        = string
}
