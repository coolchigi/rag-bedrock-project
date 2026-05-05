variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for resources"
}

variable "project_name" {
  type        = string
  default     = "bedrock-kb"
  description = "Project name for resource naming"
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Environment (dev, staging, prod)"
}

variable "embedding_model_id" {
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
  description = "Bedrock embedding model ID"

  validation {
    condition = contains([
      "amazon.titan-embed-text-v2:0",
      "amazon.titan-embed-text-v1",
      "cohere.embed-english-v3",
      "cohere.embed-multilingual-v3"
    ], var.embedding_model_id)
    error_message = "Invalid embedding model. Choose from: titan-v2, titan-v1, cohere-english, cohere-multilingual"
  }
}

variable "titan_v2_dimensions" {
  type        = number
  default     = 1024
  description = "Vector dimensions for Titan V2 (256, 512, or 1024)"

  validation {
    condition     = contains([256, 512, 1024], var.titan_v2_dimensions)
    error_message = "Titan V2 dimensions must be 256, 512, or 1024"
  }
}

variable "data_source_bucket_name" {
  type        = string
  description = "S3 bucket name for PDF documents (created if doesn't exist)"
}

variable "chunking_strategy" {
  type        = string
  default     = "FIXED_SIZE"
  description = "Chunking strategy: FIXED_SIZE, HIERARCHICAL, SEMANTIC, NONE"

  validation {
    condition     = contains(["FIXED_SIZE", "HIERARCHICAL", "SEMANTIC", "NONE"], var.chunking_strategy)
    error_message = "Invalid chunking strategy"
  }
}

variable "chunk_max_tokens" {
  type        = number
  default     = 300
  description = "Maximum tokens per chunk"
}

variable "chunk_overlap_percentage" {
  type        = number
  default     = 20
  description = "Percentage overlap between chunks"
}
