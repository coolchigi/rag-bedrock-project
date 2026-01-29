variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming"
}

variable "knowledge_base_id" {
  type        = string
  description = "Knowledge Base ID"
}

variable "data_source_bucket_name" {
  type        = string
  description = "S3 bucket name for documents"
}

variable "chunking_strategy" {
  type        = string
  description = "Chunking strategy"
}

variable "chunk_max_tokens" {
  type        = number
  description = "Maximum tokens per chunk"
}

variable "chunk_overlap_percentage" {
  type        = number
  description = "Percentage overlap between chunks"
}
