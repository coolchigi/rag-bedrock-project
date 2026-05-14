# =============================================================================
# Lambda role inline policies
# Attached here because they reference the KB and data source ARNs, which are
# only known after the bedrock module runs.
# =============================================================================

resource "aws_iam_role_policy" "ingestion_bedrock" {
  name = "bedrock-start-ingestion"
  role = var.ingestion_lambda_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock:StartIngestionJob"]
      Resource = [var.knowledge_base_arn]
    }]
  })
}

resource "aws_iam_role_policy" "query_bedrock" {
  name = "bedrock-retrieve-and-generate"
  role = var.query_lambda_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock-agent-runtime:Retrieve",
        "bedrock-agent-runtime:RetrieveAndGenerate"
      ]
      Resource = [var.knowledge_base_arn]
    }]
  })
}

# =============================================================================
# CloudWatch log groups — created explicitly so we control the retention period.
# Without this, Lambda auto-creates log groups with no retention (logs
# accumulate forever).
# =============================================================================

resource "aws_cloudwatch_log_group" "ingestion" {
  name              = "/aws/lambda/${var.name_prefix}-ingestion"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "query" {
  name              = "/aws/lambda/${var.name_prefix}-query"
  retention_in_days = 30
}

# =============================================================================
# Lambda source packaging
# =============================================================================

data "archive_file" "ingestion" {
  type        = "zip"
  source_dir  = "${path.module}/src/ingestion"
  output_path = "${path.module}/dist/ingestion.zip"
}

data "archive_file" "query" {
  type        = "zip"
  source_dir  = "${path.module}/src/query"
  output_path = "${path.module}/dist/query.zip"
}

# =============================================================================
# Ingestion Lambda
# Triggered by S3 ObjectCreated events. Starts a Bedrock ingestion job so
# documents are chunked, embedded, and indexed automatically on upload.
# =============================================================================

resource "aws_lambda_function" "ingestion" {
  function_name    = "${var.name_prefix}-ingestion"
  role             = var.ingestion_lambda_role_arn
  handler          = "index.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.ingestion.output_path
  source_code_hash = data.archive_file.ingestion.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = var.knowledge_base_id
      DATA_SOURCE_ID    = var.data_source_id
    }
  }

  reserved_concurrent_executions = 10

  depends_on = [aws_cloudwatch_log_group.ingestion]
}

# S3 triggers Lambda asynchronously. Lambda retries failed async invocations
# twice by default — one upload could trigger 3 ingestion jobs.
# Setting maximum_retry_attempts = 0 disables retries on the ingestion function.
resource "aws_lambda_function_event_invoke_config" "ingestion" {
  function_name          = aws_lambda_function.ingestion.function_name
  maximum_retry_attempts = 0
}

# Grants S3 permission to invoke this function.
# The corresponding aws_s3_bucket_notification is in the root module because
# it requires both the storage module (bucket ID) and this module (Lambda ARN).
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.data_source_bucket_name}"
}

# =============================================================================
# Query Lambda
# Invoked directly by the user. Calls Bedrock RetrieveAndGenerate and returns
# an answer plus the S3 source citations.
# =============================================================================

resource "aws_lambda_function" "query" {
  function_name    = "${var.name_prefix}-query"
  role             = var.query_lambda_role_arn
  handler          = "index.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.query.output_path
  source_code_hash = data.archive_file.query.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory

  environment {
    variables = {
      KNOWLEDGE_BASE_ID  = var.knowledge_base_id
      INFERENCE_MODEL_ID = var.inference_model_id
    }
  }

  reserved_concurrent_executions = 10

  depends_on = [aws_cloudwatch_log_group.query]
}
