###############################################################################
# Root Variables
###############################################################################

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Deployment environment (prod, staging, dev)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "Environment must be one of: prod, staging, dev."
  }
}

# --- Networking ---

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to use (2 or 3)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

# --- Web Tier ---

variable "web_instance_type" {
  description = "EC2 instance type for web tier"
  type        = string
  default     = "t3.micro"
}

variable "web_min_size" {
  description = "Minimum number of web tier instances"
  type        = number
  default     = 2
}

variable "web_max_size" {
  description = "Maximum number of web tier instances"
  type        = number
  default     = 6
}

variable "web_desired_capacity" {
  description = "Desired number of web tier instances"
  type        = number
  default     = 2
}

variable "enable_https" {
  description = "Enable HTTPS on the public ALB (requires certificate_arn)"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (required if enable_https = true)"
  type        = string
  default     = ""
}

# --- App Tier ---

variable "app_instance_type" {
  description = "EC2 instance type for app tier"
  type        = string
  default     = "t3.small"
}

variable "app_min_size" {
  description = "Minimum number of app tier instances"
  type        = number
  default     = 2
}

variable "app_max_size" {
  description = "Maximum number of app tier instances"
  type        = number
  default     = 6
}

variable "app_desired_capacity" {
  description = "Desired number of app tier instances"
  type        = number
  default     = 2
}

# --- Database Tier ---

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS (recommended for production)"
  type        = bool
  default     = true
}

variable "db_allocated_storage" {
  description = "Allocated storage in GiB for RDS"
  type        = number
  default     = 20
}

variable "db_deletion_protection" {
  description = "Enable deletion protection on RDS instance"
  type        = bool
  default     = true
}
