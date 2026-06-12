data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  query_function_name  = "${var.config.environment}-${var.config.project_name}-query"
  ingest_function_name = "${var.config.environment}-${var.config.project_name}-ingest"
  partition            = data.aws_partition.current.partition
  account_id           = data.aws_caller_identity.current.account_id
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = "${path.module}/../../.build/lambda.zip"
}

# =============================================================================
# Query Lambda
# =============================================================================

resource "aws_iam_role" "query" {
  name = "${var.config.environment}-${var.config.project_name}-query-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "query_bedrock" {
  name = "bedrock-retrieve-and-generate"
  role = aws_iam_role.query.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:RetrieveAndGenerate", "bedrock:Retrieve"]
        Resource = var.kb_arn
      },
      {
        Effect   = "Allow"
        Action   = "bedrock:InvokeModel"
        Resource = "arn:${local.partition}:bedrock:${var.config.aws_region}::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0"
      }
    ]
  })
}

resource "aws_iam_role_policy" "query_logs" {
  name = "cloudwatch-logs"
  role = aws_iam_role.query.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${local.partition}:logs:${var.config.aws_region}:${local.account_id}:log-group:/aws/lambda/${local.query_function_name}:*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "query" {
  name              = "/aws/lambda/${local.query_function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "query" {
  function_name = local.query_function_name
  role          = aws_iam_role.query.arn
  handler       = "query.handler"
  runtime       = "nodejs20.x"
  architectures = ["arm64"]
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = var.kb_id
    }
  }

  depends_on = [aws_cloudwatch_log_group.query]
}

resource "aws_cloudwatch_metric_alarm" "query_errors" {
  alarm_name          = "${local.query_function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Query Lambda errors detected"

  dimensions = {
    FunctionName = aws_lambda_function.query.function_name
  }

  alarm_actions = [var.sns_topic_arn]
}

# =============================================================================
# Ingest Lambda
# =============================================================================

resource "aws_iam_role" "ingest" {
  name = "${var.config.environment}-${var.config.project_name}-ingest-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ingest_bedrock" {
  name = "bedrock-start-ingestion"
  role = aws_iam_role.ingest.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "bedrock:StartIngestionJob"
        Resource = var.kb_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "ingest_logs" {
  name = "cloudwatch-logs"
  role = aws_iam_role.ingest.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${local.partition}:logs:${var.config.aws_region}:${local.account_id}:log-group:/aws/lambda/${local.ingest_function_name}:*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "ingest" {
  name              = "/aws/lambda/${local.ingest_function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "ingest" {
  function_name = local.ingest_function_name
  role          = aws_iam_role.ingest.arn
  handler       = "ingest.handler"
  runtime       = "nodejs20.x"
  architectures = ["arm64"]
  timeout       = 15
  memory_size   = 128

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = var.kb_id
      DATA_SOURCE_ID    = var.data_source_id
    }
  }

  depends_on = [aws_cloudwatch_log_group.ingest]
}

resource "aws_lambda_permission" "s3_invoke_ingest" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.bucket_arn
  source_account = local.account_id
}

resource "aws_s3_bucket_notification" "documents" {
  bucket = var.bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.ingest.arn
    events             = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3_invoke_ingest]
}

resource "aws_cloudwatch_metric_alarm" "ingest_errors" {
  alarm_name          = "${local.ingest_function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Ingest Lambda errors detected"

  dimensions = {
    FunctionName = aws_lambda_function.ingest.function_name
  }

  alarm_actions = [var.sns_topic_arn]
}
