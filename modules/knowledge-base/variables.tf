variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming"
}

variable "embedding_model_id" {
  type        = string
  description = "Bedrock embedding model ID"
}

variable "collection_arn" {
  type        = string
  description = "OpenSearch Serverless collection ARN"
}

variable "vector_index_name" {
  type        = string
  description = "Vector index name"
}

variable "vector_field_name" {
  type        = string
  description = "Vector field name in index"
}

variable "text_field_name" {
  type        = string
  description = "Text field name in index"
}

variable "metadata_field_name" {
  type        = string
  description = "Metadata field name in index"
}

variable "data_source_bucket_arn" {
  type        = string
  description = "S3 bucket ARN for data source"
}
