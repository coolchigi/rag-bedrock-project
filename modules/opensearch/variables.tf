variable "config" {
  description = "Global configuration object from root"
  type = object({
    project_name         = string
    environment          = string
    aws_region           = string
    embedding_dimensions = number
  })
}

variable "bedrock_kb_role_arn" {
  description = "Bedrock KB IAM role ARN for AOSS data access policy"
  type        = string
}

variable "deployer_arn" {
  description = "ARN of the IAM identity running Terraform. Added to the AOSS data access policy so the opensearch provider can create the vector index during apply."
  type        = string
}
