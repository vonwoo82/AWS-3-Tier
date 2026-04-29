###############################################################################
# AWS 3-Tier Architecture - Root Module
# Tiers: Web (ALB + EC2 ASG) | App (ALB + EC2 ASG) | DB (RDS Multi-AZ)
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment to use S3 backend for remote state
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "3tier/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

###############################################################################
# Data Sources
###############################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

###############################################################################
# Modules
###############################################################################

module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  az_count           = var.az_count
}

module "security_groups" {
  source = "./modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = var.vpc_cidr
}

module "web_tier" {
  source = "./modules/web-tier"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  web_sg_id             = module.security_groups.web_sg_id
  alb_sg_id             = module.security_groups.public_alb_sg_id
  ami_id                = data.aws_ami.amazon_linux_2023.id
  instance_type         = var.web_instance_type
  min_size              = var.web_min_size
  max_size              = var.web_max_size
  desired_capacity      = var.web_desired_capacity
  app_alb_dns_name      = module.app_tier.app_alb_dns_name
  certificate_arn       = var.certificate_arn
  enable_https          = var.enable_https
}

module "app_tier" {
  source = "./modules/app-tier"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_app_subnet_ids
  app_sg_id           = module.security_groups.app_sg_id
  alb_sg_id           = module.security_groups.private_alb_sg_id
  ami_id              = data.aws_ami.amazon_linux_2023.id
  instance_type       = var.app_instance_type
  min_size            = var.app_min_size
  max_size            = var.app_max_size
  desired_capacity    = var.app_desired_capacity
  db_endpoint         = module.db_tier.db_endpoint
  db_name             = var.db_name
  db_secret_arn       = module.db_tier.db_secret_arn
}

module "db_tier" {
  source = "./modules/db-tier"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  db_subnet_ids      = module.vpc.private_db_subnet_ids
  db_sg_id           = module.security_groups.db_sg_id
  db_name            = var.db_name
  db_username        = var.db_username
  db_instance_class  = var.db_instance_class
  db_engine_version  = var.db_engine_version
  multi_az           = var.db_multi_az
  allocated_storage  = var.db_allocated_storage
  deletion_protection = var.db_deletion_protection
}
