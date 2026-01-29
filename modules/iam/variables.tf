variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming"
}

variable "knowledge_base_arn" {
  type        = string
  description = "Bedrock Knowledge Base ARN for scoped Lambda permissions"
}

variable "embedding_model_arn" {
  type        = string
  description = "Bedrock embedding model ARN for scoped InvokeModel permissions"
}

variable "enable_vpc" {
  type        = bool
  default     = true
  description = "Whether Lambda runs in VPC (adds ENI permissions)"
}
