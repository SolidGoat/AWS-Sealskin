variable "workload_name" {
  type        = string
  description = "Workload name"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "The target AWS region (e.g., us-east-1, eu-west-1)"
}

variable "custom_tags" {
  type        = map(string)
  description = "A dynamic map of custom tags passed from global.tfvars"
  default     = {}
}
