resource "aws_opensearchserverless_security_policy" "encryption" {
  name = "${var.name_prefix}-encryption"
  type = "encryption"
  policy = jsonencode({
    Rules = [
      {
        Resource = ["collection/${var.name_prefix}-collection"]
        ResourceType = "collection"
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name = "${var.name_prefix}-network"
  type = "network"
  policy = jsonencode([
    {
      Rules = [
        {
          Resource = ["collection/${var.name_prefix}-collection"]
          ResourceType = "collection"
        }
      ]
      AllowFromPublic = true
      SourceServices = ["bedrock.amazonaws.com"]
    }
  ])
}

resource "aws_opensearchserverless_collection" "kb_collection" {
  name = "${var.name_prefix}-collection"
  type = "VECTORSEARCH"
  
  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network
  ]
}

resource "aws_opensearchserverless_access_policy" "data_access" {
  name = "${var.name_prefix}-access"
  type = "data"
  policy = jsonencode([
    {
      Rules = [
        {
          Resource = ["collection/${var.name_prefix}-collection"]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
          ResourceType = "collection"
        },
        {
          Resource = ["index/${var.name_prefix}-collection/*"]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument",
            "aoss:UpdateIndex",
            "aoss:DeleteIndex"
          ]
          ResourceType = "index"
        }
      ]
      Principal = [var.kb_role_arn]
    }
  ])
}

resource "opensearch_index" "kb_index" {
  name               = "bedrock-knowledge-base-index"
  number_of_shards   = 2
  number_of_replicas = 0
  
  mappings = jsonencode({
    properties = {
      "${var.vector_field_name}" = {
        type      = "knn_vector"
        dimension = var.vector_dimensions
        method = {
          engine      = "faiss"
          space_type  = "l2"
          name        = "hnsw"
        }
      }
      "${var.text_field_name}" = {
        type = "text"
      }
      "${var.metadata_field_name}" = {
        type = "text"
      }
    }
  })
  
  depends_on = [
    aws_opensearchserverless_collection.kb_collection,
    aws_opensearchserverless_access_policy.data_access
  ]
}
