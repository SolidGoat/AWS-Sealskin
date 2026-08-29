variable "environment" {
  type        = string
  description = "Environment type (prod, dev, staging)"
}

variable "workload_name" {
  type        = string
  description = "Workload name"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}
