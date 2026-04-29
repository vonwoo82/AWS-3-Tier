output "web_alb_dns_name" { value = aws_lb.web.dns_name }
output "web_alb_zone_id"  { value = aws_lb.web.zone_id }
output "web_asg_name"     { value = aws_autoscaling_group.web.name }
output "web_tg_arn"       { value = aws_lb_target_group.web.arn }
