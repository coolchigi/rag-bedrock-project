provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

provider "opensearch" {
  url         = module.vector_store.collection_endpoint
  aws_region  = var.aws_region
  healthcheck = false
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  embedding_model_dimensions = {
    "amazon.titan-embed-text-v2:0"     = var.titan_v2_dimensions
    "amazon.titan-embed-text-v1"       = 1536
    "cohere.embed-english-v3"          = 1024
    "cohere.embed-multilingual-v3"     = 1024
  }
  
  vector_dimensions = lookup(local.embedding_model_dimensions, var.embedding_model_id, 1024)
}

module "vector_store" {
  source = "./modules/vector-store"

  name_prefix        = local.name_prefix
  vector_dimensions  = local.vector_dimensions
  kb_role_arn        = module.knowledge_base.kb_role_arn
}

module "knowledge_base" {
  source = "./modules/knowledge-base"

  name_prefix         = local.name_prefix
  embedding_model_id  = var.embedding_model_id
  collection_arn      = module.vector_store.collection_arn
  vector_index_name   = module.vector_store.vector_index_name
  vector_field_name   = module.vector_store.vector_field_name
  text_field_name     = module.vector_store.text_field_name
  metadata_field_name = module.vector_store.metadata_field_name
  data_source_bucket_arn = module.data_source.bucket_arn
}

module "data_source" {
  source = "./modules/data-source"

  name_prefix             = local.name_prefix
  knowledge_base_id       = module.knowledge_base.knowledge_base_id
  data_source_bucket_name = var.data_source_bucket_name
  chunking_strategy       = var.chunking_strategy
  chunk_max_tokens        = var.chunk_max_tokens
  chunk_overlap_percentage = var.chunk_overlap_percentage
}

resource "time_sleep" "iam_propagation" {
  create_duration = "20s"
  depends_on = [
    module.knowledge_base,
    module.vector_store
  ]
}
