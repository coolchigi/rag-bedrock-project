variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "rag-pipeline"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "us-east-1"
}
