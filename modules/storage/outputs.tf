output "bucket_id" {
  description = "Bucket ID — used to wire the S3 notification in the root module"
  value       = aws_s3_bucket.documents.id
}

output "bucket_arn" {
  value = aws_s3_bucket.documents.arn
}

output "bucket_name" {
  value = aws_s3_bucket.documents.bucket
}
