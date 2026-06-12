output "query_function_name" {
  description = "Query Lambda function name"
  value       = aws_lambda_function.query.function_name
}

output "query_function_arn" {
  description = "Query Lambda function ARN"
  value       = aws_lambda_function.query.arn
}

output "query_invoke_arn" {
  description = "Query Lambda invoke ARN (for future API Gateway integration)"
  value       = aws_lambda_function.query.invoke_arn
}

output "ingest_function_name" {
  description = "Ingest Lambda function name"
  value       = aws_lambda_function.ingest.function_name
}

output "ingest_function_arn" {
  description = "Ingest Lambda function ARN"
  value       = aws_lambda_function.ingest.arn
}
