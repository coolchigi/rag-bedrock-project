output "bucket_id" {
  description = "Document bucket name"
  value       = aws_s3_bucket.documents.id
}

output "bucket_arn" {
  description = "Document bucket ARN"
  value       = aws_s3_bucket.documents.arn
}
