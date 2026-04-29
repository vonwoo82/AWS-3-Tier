output "public_alb_sg_id"  { value = aws_security_group.public_alb.id }
output "web_sg_id"         { value = aws_security_group.web.id }
output "private_alb_sg_id" { value = aws_security_group.private_alb.id }
output "app_sg_id"         { value = aws_security_group.app.id }
output "db_sg_id"          { value = aws_security_group.db.id }
