variable "config" {
  description = "Global configuration object from root"
  type = object({
    project_name                = string
    environment                 = string
    aws_region                  = string
    embedding_dimensions        = number
  })
}

variable "kb_id" {
  description = "Bedrock Knowledge Base ID"
  type        = string
}

variable "kb_arn" {
  description = "Bedrock Knowledge Base ARN for IAM policy"
  type        = string
}

variable "data_source_id" {
  description = "Bedrock data source ID for ingestion jobs"
  type        = string
}

variable "bucket_id" {
  description = "S3 document bucket name for event notifications"
  type        = string
}

variable "bucket_arn" {
  description = "S3 document bucket ARN for IAM policy"
  type        = string
}

variable "lambda_source_dir" {
  description = "Path to the Lambda source directory"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for error alerts"
  type        = string
}
