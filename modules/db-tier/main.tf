###############################################################################
# Module: DB Tier
# Creates: Secrets Manager secret (auto-generated password), RDS MySQL
#          Multi-AZ instance, parameter group, and CloudWatch alarms.
###############################################################################

###############################################################################
# Secrets Manager — auto-generate and store DB credentials
###############################################################################

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project_name}/${var.environment}/db-credentials"
  description             = "RDS master credentials for ${var.project_name} ${var.environment}"
  recovery_window_in_days = 7

  tags = { Name = "${var.project_name}-${var.environment}-db-secret" }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    engine   = "mysql"
    host     = aws_db_instance.main.address
    port     = 3306
    dbname   = var.db_name
  })

  # Re-run after the RDS instance is created so host is populated
  depends_on = [aws_db_instance.main]
}

resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

###############################################################################
# RDS Parameter Group
###############################################################################

resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-${var.environment}-mysql8"
  family = "mysql8.0"

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  parameter {
    name  = "log_output"
    value = "FILE"
  }

  tags = { Name = "${var.project_name}-${var.environment}-mysql8-pg" }
}

###############################################################################
# DB Subnet Group (re-used from VPC module via variable)
###############################################################################

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = { Name = "${var.project_name}-${var.environment}-db-subnet-group" }
}

###############################################################################
# RDS MySQL Instance
###############################################################################

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-mysql"

  # Engine
  engine               = "mysql"
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 3   # auto-scaling upper bound
  storage_type          = "gp3"
  storage_encrypted     = true

  # Credentials
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_sg_id]
  publicly_accessible    = false

  # High Availability
  multi_az = var.multi_az

  # Parameter & option groups
  parameter_group_name = aws_db_parameter_group.main.name

  # Backup
  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "Mon:04:00-Mon:05:00"
  copy_tags_to_snapshot     = true
  delete_automated_backups  = false
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot"

  # Protection
  deletion_protection = var.deletion_protection

  # Monitoring
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn
  enabled_cloudwatch_logs_exports = ["error", "slowquery", "general"]
  performance_insights_enabled = true
  performance_insights_retention_period = 7

  tags = { Name = "${var.project_name}-${var.environment}-mysql" }
}

###############################################################################
# Enhanced Monitoring IAM Role
###############################################################################

resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

###############################################################################
# CloudWatch Alarms
###############################################################################

resource "aws_cloudwatch_metric_alarm" "db_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-db-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is too high"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "db_free_storage_low" {
  alarm_name          = "${var.project_name}-${var.environment}-db-free-storage-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120 # 5 GiB in bytes
  alarm_description   = "RDS free storage space is below 5 GiB"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "db_connections_high" {
  alarm_name          = "${var.project_name}-${var.environment}-db-connections-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 120
  statistic           = "Average"
  threshold           = 200
  alarm_description   = "RDS connection count is unusually high"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "db_read_latency_high" {
  alarm_name          = "${var.project_name}-${var.environment}-db-read-latency"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 0.05 # 50 ms
  alarm_description   = "RDS read latency exceeded 50ms"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
}
