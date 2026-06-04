variable "config" {
  description = "Global configuration object from root"
  type = object({
    project_name         = string
    environment          = string
    aws_region           = string
    embedding_dimensions = number
  })
}

variable "bucket_arn" {
  description = "S3 document bucket ARN"
  type        = string
}

variable "collection_arn" {
  description = "AOSS collection ARN"
  type        = string
}

variable "collection_endpoint" {
  description = "AOSS collection endpoint URL"
  type        = string
}
