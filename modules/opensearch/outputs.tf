output "collection_arn" {
  value = aws_opensearchserverless_collection.main.arn
}

output "collection_endpoint" {
  description = "HTTPS endpoint used by the opensearch provider to create the index"
  value       = aws_opensearchserverless_collection.main.collection_endpoint
}

output "collection_name" {
  description = "Collection name — used to build OSS data access policy patterns in the root module"
  value       = local.collection_name
}
