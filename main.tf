data "aws_caller_identity" "current" {}

locals {
  config = {
    project_name                = var.project_name
    environment                 = var.environment
    aws_region                  = var.aws_region
    embedding_dimensions        = var.embedding_dimensions
  }
}

resource "aws_sns_topic" "alerts" {
  name = "${var.environment}-${var.project_name}-alerts"
}

module "storage" {
  source = "./modules/storage"
  config = local.config
}

module "bedrock" {
  source = "./modules/bedrock"
  config = local.config

  bucket_arn          = module.storage.bucket_arn
  collection_arn      = module.opensearch.collection_arn
  collection_endpoint = module.opensearch.collection_endpoint
}

module "opensearch" {
  source = "./modules/opensearch"
  config = local.config

  bedrock_kb_role_arn = module.bedrock.kb_role_arn
  deployer_arn        = data.aws_caller_identity.current.arn
}

resource "opensearch_index" "bedrock_kb" {
  name          = "bedrock-knowledge-base-default-index"
  index_knn     = true
  force_destroy = true

  mappings = jsonencode({
    properties = {
      "bedrock-knowledge-base-default-vector" = {
        type      = "knn_vector"
        dimension = var.embedding_dimensions
        method = {
          name       = "hnsw"
          engine     = "faiss"
          space_type = "l2"
          parameters = {
            ef_construction = 512
            m               = 16
          }
        }
      }
      "AMAZON_BEDROCK_TEXT_CHUNK" = {
        type = "text"
      }
      "AMAZON_BEDROCK_METADATA" = {
        type  = "text"
        index = false
      }
    }
  })

  lifecycle {
    precondition {
      condition     = var.opensearch_collection_endpoint != "https://placeholder.us-east-1.aoss.amazonaws.com"
      error_message = "Set opensearch_collection_endpoint in terraform.tfvars to the value from 'terraform output collection_endpoint' before running the full apply."
    }
  }

  depends_on = [module.opensearch]
}

module "lambda" {
  source = "./modules/lambda"
  config = local.config

  kb_id             = module.bedrock.kb_id
  kb_arn            = module.bedrock.kb_arn
  data_source_id    = module.bedrock.data_source_id
  bucket_id         = module.storage.bucket_id
  bucket_arn        = module.storage.bucket_arn
  lambda_source_dir = "${path.root}/lambda/src"
  sns_topic_arn     = aws_sns_topic.alerts.arn
}
