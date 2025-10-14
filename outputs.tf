output "s3_bucket_name" {
  description = "Name of the S3 bucket for PDF documents"
  value       = aws_s3_bucket.knowledge_base_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.knowledge_base_bucket.arn
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "opensearch_collection_endpoint" {
  description = "Endpoint of the OpenSearch Serverless collection"
  value       = aws_opensearchserverless_collection.knowledge_base.collection_endpoint
}

output "opensearch_collection_arn" {
  description = "ARN of the OpenSearch Serverless collection"
  value       = aws_opensearchserverless_collection.knowledge_base.arn
}

output "knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base"
  value       = aws_bedrockagent_knowledge_base.main.id
}

output "knowledge_base_arn" {
  description = "ARN of the Bedrock Knowledge Base"
  value       = aws_bedrockagent_knowledge_base.main.arn
}

output "data_source_id" {
  description = "ID of the Bedrock Knowledge Base Data Source"
  value       = aws_bedrockagent_data_source.main.id
}

output "bedrock_kb_role_arn" {
  description = "ARN of the IAM role used by Bedrock Knowledge Base"
  value       = aws_iam_role.bedrock_kb_role.arn
}
