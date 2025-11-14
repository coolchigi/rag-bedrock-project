output "knowledge_base_id" {
  description = "Knowledge Base ID for UI/API integration"
  value       = module.knowledge_base.knowledge_base_id
}

output "data_source_id" {
  description = "Data Source ID for triggering ingestion"
  value       = module.data_source.data_source_id
}

output "s3_bucket_name" {
  description = "S3 bucket for PDF uploads"
  value       = module.data_source.bucket_name
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = module.data_source.bucket_arn
}

output "collection_endpoint" {
  description = "OpenSearch Serverless collection endpoint"
  value       = module.vector_store.collection_endpoint
}

output "kb_role_arn" {
  description = "Knowledge Base IAM role ARN (for UI Lambda to assume)"
  value       = module.knowledge_base.kb_role_arn
}

output "vector_index_name" {
  description = "Vector index name in OpenSearch"
  value       = module.vector_store.vector_index_name
}

output "embedding_model_arn" {
  description = "Embedding model ARN"
  value       = module.knowledge_base.embedding_model_arn
}

output "deployment_commands" {
  description = "Next steps for deployment"
  value = <<-EOT
    # Upload documents:
    aws s3 cp ./documents/ s3://${module.data_source.bucket_name}/ --recursive
    
    # Trigger ingestion:
    aws bedrock-agent start-ingestion-job \
      --knowledge-base-id ${module.knowledge_base.knowledge_base_id} \
      --data-source-id ${module.data_source.data_source_id}
    
    # Test retrieval:
    aws bedrock-agent-runtime retrieve \
      --knowledge-base-id ${module.knowledge_base.knowledge_base_id} \
      --retrieval-query text="Your test query"
  EOT
}
