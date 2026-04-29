###############################################################################
# Root Outputs
###############################################################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets (Web Tier)"
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of private subnets (App Tier)"
  value       = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "IDs of private subnets (DB Tier)"
  value       = module.vpc.private_db_subnet_ids
}

output "web_alb_dns_name" {
  description = "Public DNS name of the Web ALB (entry point)"
  value       = module.web_tier.web_alb_dns_name
}

output "web_alb_zone_id" {
  description = "Zone ID of the Web ALB (for Route 53 alias records)"
  value       = module.web_tier.web_alb_zone_id
}

output "app_alb_dns_name" {
  description = "Internal DNS name of the App ALB"
  value       = module.app_tier.app_alb_dns_name
}

output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = module.db_tier.db_endpoint
  sensitive   = true
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding DB credentials"
  value       = module.db_tier.db_secret_arn
}

output "web_asg_name" {
  description = "Name of the Web tier Auto Scaling Group"
  value       = module.web_tier.web_asg_name
}

output "app_asg_name" {
  description = "Name of the App tier Auto Scaling Group"
  value       = module.app_tier.app_asg_name
}
