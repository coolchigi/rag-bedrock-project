variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "project_name" {
  type        = string
  default     = "bedrock-kb"
  description = "Project name"
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Environment"
}
