variable "workload_name" {
  type        = string
  description = "Workload name"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "custom_tags" {
  type        = map(string)
  description = "A dynamic map of custom tags passed from global.tfvars"
  default     = {}
}
