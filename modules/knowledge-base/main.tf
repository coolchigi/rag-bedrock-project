data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_bedrock_foundation_model" "embedding" {
  model_id = var.embedding_model_id
}

resource "aws_iam_role" "kb_role" {
  name = "${var.name_prefix}-kb-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "kb_bedrock_model" {
  name = "bedrock-model-access"
  role = aws_iam_role.kb_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = [data.aws_bedrock_foundation_model.embedding.model_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy" "kb_s3_access" {
  name = "s3-data-source-access"
  role = aws_iam_role.kb_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.data_source_bucket_arn,
          "${var.data_source_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "kb_opensearch_access" {
  name = "opensearch-access"
  role = aws_iam_role.kb_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["aoss:APIAccessAll"]
        Resource = [var.collection_arn]
      }
    ]
  })
}

resource "time_sleep" "kb_iam_propagation" {
  create_duration = "20s"
  depends_on = [
    aws_iam_role_policy.kb_bedrock_model,
    aws_iam_role_policy.kb_s3_access,
    aws_iam_role_policy.kb_opensearch_access
  ]
}

resource "aws_bedrockagent_knowledge_base" "kb" {
  name     = "${var.name_prefix}-kb"
  role_arn = aws_iam_role.kb_role.arn
  
  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = data.aws_bedrock_foundation_model.embedding.model_arn
    }
  }
  
  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = var.collection_arn
      vector_index_name = var.vector_index_name
      field_mapping {
        vector_field   = var.vector_field_name
        text_field     = var.text_field_name
        metadata_field = var.metadata_field_name
      }
    }
  }
  
  depends_on = [time_sleep.kb_iam_propagation]
}
