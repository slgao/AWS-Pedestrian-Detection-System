resource "aws_autoscaling_group" "frontend" {
  name             = "frontend-asg"
  min_size         = 2
  desired_capacity = 2
  max_size         = 4
  launch_template {
    id      = var.launch_template_id
    version = "$Latest"
  }
  vpc_zone_identifier       = var.subnet_ids  # Now using private subnets
  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300 # seconds, default 300
  tag {
    key                 = "Name"
    value               = "frontend-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "frontend-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.frontend.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0 # 70
  }
}
