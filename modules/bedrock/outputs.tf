output "kb_role_arn" {
  description = "Bedrock KB IAM role ARN (created early for AOSS access policy)"
  value       = aws_iam_role.kb.arn
}

output "kb_id" {
  description = "Bedrock Knowledge Base ID"
  value       = aws_bedrockagent_knowledge_base.main.id
}

output "kb_arn" {
  description = "Bedrock Knowledge Base ARN"
  value       = aws_bedrockagent_knowledge_base.main.arn
}

output "data_source_id" {
  description = "Bedrock data source ID"
  value       = aws_bedrockagent_data_source.s3.data_source_id
}
