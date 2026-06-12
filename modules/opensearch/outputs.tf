output "collection_arn" {
  description = "AOSS collection ARN"
  value       = aws_opensearchserverless_collection.vectors.arn
}

output "collection_endpoint" {
  description = "AOSS collection endpoint URL"
  value       = aws_opensearchserverless_collection.vectors.collection_endpoint
}

output "collection_name" {
  description = "AOSS collection name"
  value       = aws_opensearchserverless_collection.vectors.name
}
