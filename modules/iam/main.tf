data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Lambda execution role for RAG queries
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.name_prefix}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC networking permissions (required for Lambda in VPC)
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  count      = var.enable_vpc ? 1 : 0
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Scoped Bedrock permissions - least privilege
resource "aws_iam_role_policy" "lambda_bedrock_access" {
  name = "bedrock-access"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInvokeModel"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          var.embedding_model_arn,
          # Allow common inference models (Claude, Titan) - scoped to account region
          "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/anthropic.*",
          "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/amazon.*"
        ]
      },
      {
        Sid    = "BedrockKnowledgeBaseAccess"
        Effect = "Allow"
        Action = [
          "bedrock-agent-runtime:Retrieve",
          "bedrock-agent-runtime:RetrieveAndGenerate"
        ]
        Resource = [var.knowledge_base_arn]
      }
    ]
  })
}
