###############################################################################
# Example variable values — copy and customise for your environment
###############################################################################

aws_region   = "us-east-1"
project_name = "myapp"
environment  = "prod"

# Networking
vpc_cidr = "10.0.0.0/16"
az_count = 2

# Web Tier
web_instance_type    = "t3.micro"
web_min_size         = 2
web_max_size         = 6
web_desired_capacity = 2
enable_https         = false   # set true + provide certificate_arn for HTTPS
# certificate_arn    = "arn:aws:acm:us-east-1:123456789012:certificate/..."

# App Tier
app_instance_type    = "t3.small"
app_min_size         = 2
app_max_size         = 6
app_desired_capacity = 2

# Database Tier
db_name                = "appdb"
db_username            = "dbadmin"
db_instance_class      = "db.t3.medium"
db_engine_version      = "8.0"
db_multi_az            = true
db_allocated_storage   = 20
db_deletion_protection = true
