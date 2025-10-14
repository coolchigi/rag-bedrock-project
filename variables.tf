variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name to be used as a prefix for resource names"
  type        = string
  default     = "rag-bedrock"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for storing PDF documents"
  type        = string
}

variable "embedding_model_id" {
  description = "Bedrock embedding model ID"
  type        = string
  default     = "amazon.titan-embed-text-v1"
}

variable "vector_index_name" {
  description = "Name of the vector index in OpenSearch Serverless"
  type        = string
  default     = "bedrock-knowledge-base-index"
}
