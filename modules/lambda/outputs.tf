output "ingestion_lambda_arn" {
  description = "ARN used to wire the S3 bucket notification in the root module"
  value       = aws_lambda_function.ingestion.arn
}

output "ingestion_lambda_name" {
  value = aws_lambda_function.ingestion.function_name
}

output "query_lambda_arn" {
  value = aws_lambda_function.query.arn
}

output "query_lambda_name" {
  value = aws_lambda_function.query.function_name
}
