locals {
  collection_name = "${var.name_prefix}-collection"
}

# =============================================================================
# Encryption policy — must exist before the collection is created.
# AWSOwnedKey = true uses an AWS-managed key (no extra cost or OCU requirement).
# =============================================================================

resource "aws_opensearchserverless_security_policy" "encryption" {
  name = "${var.name_prefix}-encryption"
  type = "encryption"

  policy = jsonencode({
    Rules = [{
      Resource     = ["collection/${local.collection_name}"]
      ResourceType = "collection"
    }]
    AWSOwnedKey = true
  })
}

# =============================================================================
# Network policy — controls who can reach the collection endpoint.
#
# AllowFromPublic = true is intentional here: the Terraform deployer (an IAM
# user) needs to reach the endpoint to create the OpenSearch index. Without a
# VPC endpoint, the only way to allow this is via the public endpoint.
#
# This does NOT mean the data is unprotected — access still requires both:
#   1. IAM permission (aoss:APIAccessAll) on the deployer policy, AND
#   2. An OSS data access policy listing the principal explicitly.
#
# For production with stricter network requirements, add a VPC endpoint and
# set AllowFromPublic = false with a SourceVPCEndpoints rule.
# =============================================================================

resource "aws_opensearchserverless_security_policy" "network" {
  name = "${var.name_prefix}-network"
  type = "network"

  policy = jsonencode([{
    Rules = [{
      Resource     = ["collection/${local.collection_name}"]
      ResourceType = "collection"
    }]
    AllowFromPublic = true
  }])
}

# =============================================================================
# Collection — depends on both security policies being in place first.
# =============================================================================

resource "aws_opensearchserverless_collection" "main" {
  name = local.collection_name
  type = "VECTORSEARCH"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
  ]
}
