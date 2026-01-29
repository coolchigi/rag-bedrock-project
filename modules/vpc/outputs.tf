output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "Security group ID for Lambda and OpenSearch"
  value       = aws_security_group.sg_lambda_opensearch.id
}

output "opensearch_vpc_endpoint_id" {
  description = "OpenSearch Serverless VPC endpoint ID"
  value       = aws_opensearchserverless_vpc_endpoint.aoss.id
}
