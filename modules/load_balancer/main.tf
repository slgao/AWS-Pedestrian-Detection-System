
resource "aws_lb" "frontend" {
  name               = "frontend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.public_subnet_ids
  tags = {
    Name = "frontend-alb"
  }
}

resource "aws_lb_target_group" "frontend" {
  name     = "frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    # path                = "/wp-includes/images/blank.gif"
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}
