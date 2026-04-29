output "db_endpoint"    { value = aws_db_instance.main.address; sensitive = true }
output "db_port"        { value = aws_db_instance.main.port }
output "db_secret_arn"  { value = aws_secretsmanager_secret.db.arn }
output "db_identifier"  { value = aws_db_instance.main.identifier }
