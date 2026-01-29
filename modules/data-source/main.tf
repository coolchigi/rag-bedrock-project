data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "data_source" {
  bucket = var.data_source_bucket_name
}

resource "aws_s3_bucket_versioning" "data_source" {
  bucket = aws_s3_bucket.data_source.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_source" {
  bucket = aws_s3_bucket.data_source.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data_source" {
  bucket = aws_s3_bucket.data_source.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_bedrockagent_data_source" "s3_data_source" {
  name              = "${var.name_prefix}-s3-datasource"
  knowledge_base_id = var.knowledge_base_id
  
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.data_source.arn
    }
  }
  
  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = var.chunking_strategy
      
      dynamic "fixed_size_chunking_configuration" {
        for_each = var.chunking_strategy == "FIXED_SIZE" ? [1] : []
        content {
          max_tokens         = var.chunk_max_tokens
          overlap_percentage = var.chunk_overlap_percentage
        }
      }
      
      dynamic "hierarchical_chunking_configuration" {
        for_each = var.chunking_strategy == "HIERARCHICAL" ? [1] : []
        content {
          level_configuration {
            max_tokens = var.chunk_max_tokens
          }
          level_configuration {
            max_tokens = var.chunk_max_tokens * 2
          }
          overlap_tokens = floor(var.chunk_max_tokens * var.chunk_overlap_percentage / 100)
        }
      }
      
      dynamic "semantic_chunking_configuration" {
        for_each = var.chunking_strategy == "SEMANTIC" ? [1] : []
        content {
          breakpoint_percentile_threshold = 95
          buffer_size                     = 0
          max_token                       = var.chunk_max_tokens
        }
      }
    }
  }
}
