variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming"
}

variable "vector_dimensions" {
  type        = number
  description = "Vector embedding dimensions"
}

variable "kb_role_arn" {
  type        = string
  description = "Knowledge Base IAM role ARN for data access policy"
}

variable "vector_field_name" {
  type        = string
  default     = "bedrock-knowledge-base-default-vector"
  description = "Vector field name in index"
}

variable "text_field_name" {
  type        = string
  default     = "AMAZON_BEDROCK_TEXT_CHUNK"
  description = "Text field name in index"
}

variable "metadata_field_name" {
  type        = string
  default     = "AMAZON_BEDROCK_METADATA"
  description = "Metadata field name in index"
}
