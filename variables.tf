variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
}

variable "opensearch_collection_endpoint" {
  description = "OpenSearch Serverless collection endpoint URL. Run 'terraform output collection_endpoint' after step 3a and add the value to terraform.tfvars before running the full apply."
  type        = string
  default     = "https://placeholder.us-east-1.aoss.amazonaws.com"
}

variable "embedding_dimensions" {
  description = "Titan Text Embeddings v2 vector dimensions (256 or 512)"
  type        = number

  validation {
    condition     = contains([256, 512], var.embedding_dimensions)
    error_message = "Embedding dimensions must be 256 or 512."
  }
}
