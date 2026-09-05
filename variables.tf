variable "workload_name" {
  type        = string
  description = "Workload name"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "The target AWS region (e.g., us-east-1, eu-west-1)"
}

locals {
  # Map standard AWS region strings to short-codes
  region_shortcodes = {
    "us-east-1"      = "ue1"
    "us-east-2"      = "ue2"
    "us-west-1"      = "uw1"
    "us-west-2"      = "uw2"
    "eu-west-1"      = "ew1"
    "eu-central-1"   = "ec1"
    "ap-southeast-1" = "as1"
  }

  region_short = lookup(local.region_shortcodes, var.region, var.region)
}

variable "custom_tags" {
  type        = map(string)
  description = "A dynamic map of custom tags passed from global.tfvars"
  default     = {}
}

############################################
# EC2 Instance Variables
############################################
variable "ubuntu_codename" {
  type        = string
  description = "The target Ubuntu release name (e.g., noble, resolute)"
}

variable "ubuntu_version" {
  type        = string
  description = "The target semantic version number (e.g., 24.04, 26.04)"
}

variable "instance_size" {
  type        = string
  default     = "t4g.small"
  description = "The EC2 instance size (e.g., t2.micro, t4g.small)"
}

variable "volume_size" {
  type        = number
  default     = 10
  description = "EBS volume size in GB"
}
