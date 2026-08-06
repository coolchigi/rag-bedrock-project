output "collection_endpoint" {
  description = "OpenSearch Serverless collection endpoint URL - set this as opensearch_collection_endpoint in terraform.tfvars"
  value       = module.opensearch.collection_endpoint
}

output "document_bucket_name" {
  description = "S3 bucket for uploading source documents"
  value       = module.storage.bucket_id
}

output "knowledge_base_id" {
  description = "Bedrock Knowledge Base ID (used for ingestion and queries)"
  value       = module.bedrock.kb_id
}

output "data_source_id" {
  description = "Bedrock data source ID (used for ingestion jobs)"
  value       = module.bedrock.data_source_id
}

output "query_function_name" {
  description = "Query Lambda function name for CLI invocation"
  value       = module.lambda.query_function_name
}

output "ingest_function_name" {
  description = "Ingest Lambda function name (triggered by S3 events)"
  value       = module.lambda.ingest_function_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for operational alerts"
  value       = aws_sns_topic.alerts.arn
}
