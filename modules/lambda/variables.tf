variable "name_prefix" {
  type = string
}

variable "ingestion_lambda_role_arn" {
  type = string
}

variable "ingestion_lambda_role_name" {
  type        = string
  description = "Role name used to attach the ingestion Lambda's inline IAM policy"
}

variable "query_lambda_role_arn" {
  type = string
}

variable "query_lambda_role_name" {
  type        = string
  description = "Role name used to attach the query Lambda's inline IAM policy"
}

variable "knowledge_base_id" {
  type = string
}

variable "knowledge_base_arn" {
  type        = string
  description = "Knowledge Base ARN — used to scope the query Lambda's IAM policy"
}

variable "data_source_id" {
  type = string
}

variable "data_source_bucket_name" {
  type        = string
  description = "Document bucket name — used to scope the S3 invoke permission"
}

variable "inference_model_id" {
  type    = string
  default = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "lambda_timeout" {
  type    = number
  default = 60
}

variable "lambda_memory" {
  type    = number
  default = 256
}
