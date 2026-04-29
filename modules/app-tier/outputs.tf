output "app_alb_dns_name" { value = aws_lb.app.dns_name }
output "app_asg_name"     { value = aws_autoscaling_group.app.name }
output "app_tg_arn"       { value = aws_lb_target_group.app.arn }
