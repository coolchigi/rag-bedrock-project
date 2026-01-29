output "data_source_id" {
  description = "Data Source ID"
  value       = aws_bedrockagent_data_source.s3_data_source.id
}

output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.data_source.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.data_source.arn
}
