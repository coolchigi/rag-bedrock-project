output "knowledge_base_id" {
  description = "Knowledge Base ID"
  value       = aws_bedrockagent_knowledge_base.kb.id
}

output "knowledge_base_arn" {
  description = "Knowledge Base ARN"
  value       = aws_bedrockagent_knowledge_base.kb.arn
}

output "kb_role_arn" {
  description = "Knowledge Base IAM role ARN"
  value       = aws_iam_role.kb_role.arn
}

output "kb_role_name" {
  description = "Knowledge Base IAM role name"
  value       = aws_iam_role.kb_role.name
}

output "embedding_model_arn" {
  description = "Embedding model ARN"
  value       = data.aws_bedrock_foundation_model.embedding.model_arn
}
