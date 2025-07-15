# React App Deployment Module
# This module handles deploying the React app from GitLab

# Reference AMI data module
module "ami_data" {
  source = "../ami_data"
}

# Create user data script for EC2 instances
locals {
  user_data_script = base64encode(templatefile("${path.module}/user_data.sh", {
    gitlab_repo_url = var.gitlab_repo_url
    aws_region      = var.aws_region
    s3_bucket_name  = var.s3_bucket_name
    api_endpoint    = var.api_endpoint
    environment     = var.environment
    rds_endpoint    = var.rds_endpoint
    db_name         = var.db_name
    db_username     = var.db_username
    db_password     = var.db_password
  }))
}

# Launch template for frontend instances
resource "aws_launch_template" "frontend_app" {
  name                   = "frontend-app-launch-template"
  image_id               = var.use_amazon_linux_2023 ? module.ami_data.amazon_linux_2023_id : module.ami_data.amazon_linux_2_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = var.security_group_ids
  user_data              = local.user_data_script

  # Add IAM instance profile for AWS service access
  iam_instance_profile {
    name = "LabInstanceProfile"
  }

  # # Increase EBS volume size to accommodate dependencies
  # block_device_mappings {
  #   device_name = "/dev/xvda"
  #   ebs {
  #     volume_size           = 20  # GB (increased from default 8GB)
  #     volume_type           = "gp3"
  #     delete_on_termination = true
  #     encrypted             = true
  #   }
  # }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = var.instance_name
      Environment = var.environment
      AppType     = "frontend-app"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
