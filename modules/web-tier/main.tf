###############################################################################
# Module: Web Tier
# Creates: Public ALB, target group, listener, launch template, ASG,
#          scaling policies, and CloudWatch alarms.
###############################################################################

###############################################################################
# IAM Instance Profile
###############################################################################

resource "aws_iam_role" "web" {
  name = "${var.project_name}-${var.environment}-web-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "web_ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.project_name}-${var.environment}-web-profile"
  role = aws_iam_role.web.name
}

###############################################################################
# Public ALB
###############################################################################

resource "aws_lb" "web" {
  name               = "${var.project_name}-${var.environment}-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = { Name = "${var.project_name}-${var.environment}-web-alb" }
}

resource "aws_lb_target_group" "web" {
  name        = "${var.project_name}-${var.environment}-web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = { Name = "${var.project_name}-${var.environment}-web-tg" }
}

# HTTP listener (always created — redirects to HTTPS when enable_https = true)
resource "aws_lb_listener" "web_http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.enable_https ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.enable_https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = var.enable_https ? [] : [1]
      content {
        target_group {
          arn = aws_lb_target_group.web.arn
        }
      }
    }
  }
}

# HTTPS listener (optional)
resource "aws_lb_listener" "web_https" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

###############################################################################
# Launch Template
###############################################################################

resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-${var.environment}-web-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.web.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.web_sg_id]
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    app_alb_dns = var.app_alb_dns_name
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 1
  }

  monitoring { enabled = true }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-${var.environment}-web"
      Tier = "Web"
    }
  }

  lifecycle { create_before_destroy = true }
}

###############################################################################
# Auto Scaling Group
###############################################################################

resource "aws_autoscaling_group" "web" {
  name                = "${var.project_name}-${var.environment}-web-asg"
  vpc_zone_identifier = var.public_subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-web"
    propagate_at_launch = true
  }
}

###############################################################################
# Auto Scaling Policies & CloudWatch Alarms
###############################################################################

resource "aws_autoscaling_policy" "web_scale_out" {
  name                   = "${var.project_name}-${var.environment}-web-scale-out"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "web_scale_in" {
  name                   = "${var.project_name}-${var.environment}-web-scale-in"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-web-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "Scale out when CPU >= 75%"
  alarm_actions       = [aws_autoscaling_policy.web_scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_low" {
  alarm_name          = "${var.project_name}-${var.environment}-web-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 25
  alarm_description   = "Scale in when CPU <= 25%"
  alarm_actions       = [aws_autoscaling_policy.web_scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}
