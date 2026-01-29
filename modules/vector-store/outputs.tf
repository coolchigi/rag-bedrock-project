output "collection_arn" {
  description = "OpenSearch Serverless collection ARN"
  value       = aws_opensearchserverless_collection.kb_collection.arn
}

output "collection_endpoint" {
  description = "OpenSearch Serverless collection endpoint"
  value       = aws_opensearchserverless_collection.kb_collection.collection_endpoint
}

output "vector_index_name" {
  description = "Vector index name"
  value       = opensearch_index.kb_index.name
}

output "vector_field_name" {
  description = "Vector field name"
  value       = var.vector_field_name
}

output "text_field_name" {
  description = "Text field name"
  value       = var.text_field_name
}

output "metadata_field_name" {
  description = "Metadata field name"
  value       = var.metadata_field_name
}
