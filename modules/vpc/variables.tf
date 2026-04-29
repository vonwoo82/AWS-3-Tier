###############################################################################
# Module: VPC — Variables
###############################################################################

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "az_count" {
  type = number
}
