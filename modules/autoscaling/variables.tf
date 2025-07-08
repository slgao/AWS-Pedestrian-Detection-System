variable "launch_template_id" {
  description = "ID of the launch template"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the Auto Scaling group"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}
