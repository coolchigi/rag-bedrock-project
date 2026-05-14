terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# Terraform remote state
# =============================================================================

resource "aws_s3_bucket" "state" {
  bucket = "${var.project_name}-${var.environment}-terraform-state"
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# State versioning is on so we can recover from bad applies, but old versions
# accumulate indefinitely. Expire them after 90 days.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# =============================================================================
# Deployer IAM policy
# Attach to your IAM user after bootstrap, then detach AdministratorAccess.
# Scoped to exactly what this project's terraform plan/apply needs.
# =============================================================================

resource "aws_iam_policy" "deployer" {
  name        = "${var.project_name}-${var.environment}-terraform-deployer"
  description = "Scoped permissions for the IAM principal running terraform plan/apply for this project"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # Terraform state (S3 native locking via use_lockfile = true)
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*"
        ]
      },

      # STS — needed for aws_caller_identity data source
      {
        Sid      = "STS"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      },

      # IAM — roles and inline policies for KB and Lambda
      {
        Sid    = "IAMRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
          "iam:TagRole", "iam:UntagRole", "iam:ListRoleTags",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListAttachedRolePolicies",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:UpdateAssumeRolePolicy"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-*"
      },

      # iam:PassRole scoped to only Bedrock and Lambda — prevents privilege escalation
      {
        Sid    = "PassRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = ["bedrock.amazonaws.com", "lambda.amazonaws.com"]
          }
        }
      },

      # S3 — document bucket (Terraform reads many attributes on every plan)
      {
        Sid    = "S3DocumentBucket"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket", "s3:DeleteBucket",
          "s3:GetBucketVersioning", "s3:PutBucketVersioning",
          "s3:GetEncryptionConfiguration", "s3:PutEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock", "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketAcl",
          "s3:GetBucketCORS", "s3:GetBucketWebsite", "s3:GetBucketLogging",
          "s3:GetBucketRequestPayment", "s3:GetLifecycleConfiguration",
          "s3:GetAccelerateConfiguration", "s3:GetReplicationConfiguration",
          "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketTagging", "s3:PutBucketTagging",
          "s3:ListBucket",
          "s3:GetBucketNotification", "s3:PutBucketNotification"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-*"
      },

      # OpenSearch Serverless — control plane
      {
        Sid    = "AOSS"
        Effect = "Allow"
        Action = [
          "aoss:CreateCollection", "aoss:DeleteCollection", "aoss:UpdateCollection",
          "aoss:BatchGetCollection", "aoss:ListCollections",
          "aoss:CreateSecurityPolicy", "aoss:UpdateSecurityPolicy",
          "aoss:DeleteSecurityPolicy", "aoss:GetSecurityPolicy", "aoss:ListSecurityPolicies",
          "aoss:CreateAccessPolicy", "aoss:UpdateAccessPolicy",
          "aoss:DeleteAccessPolicy", "aoss:GetAccessPolicy", "aoss:ListAccessPolicies",
          "aoss:TagResource", "aoss:UntagResource", "aoss:ListTagsForResource",
          # Data plane — required for the opensearch provider to create the index.
          # AWS does not allow scoping aoss:APIAccessAll to a specific collection ARN
          # at the IAM layer — Resource = "*" is an AWS limitation, not a mistake.
          # The OSS data access policy (in main.tf) is the second layer that scopes
          # which collections and indices each principal can actually read or write.
          "aoss:APIAccessAll"
        ]
        Resource = "*"
      },

      # Bedrock — model lookup, Knowledge Base, Data Source
      {
        Sid    = "BedrockFoundationModels"
        Effect = "Allow"
        Action = ["bedrock:GetFoundationModel", "bedrock:ListFoundationModels"]
        Resource = "*"
      },
      {
        Sid    = "BedrockKnowledgeBase"
        Effect = "Allow"
        Action = [
          "bedrock:CreateKnowledgeBase", "bedrock:DeleteKnowledgeBase",
          "bedrock:GetKnowledgeBase", "bedrock:UpdateKnowledgeBase",
          "bedrock:CreateDataSource", "bedrock:DeleteDataSource",
          "bedrock:GetDataSource", "bedrock:UpdateDataSource",
          "bedrock:TagResource", "bedrock:UntagResource", "bedrock:ListTagsForResource"
        ]
        Resource = "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
      },

      # Lambda
      {
        Sid    = "Lambda"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction", "lambda:DeleteFunction",
          "lambda:GetFunction", "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration", "lambda:GetFunctionConfiguration",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:PutFunctionConcurrency", "lambda:DeleteFunctionConcurrency",
          "lambda:GetFunctionConcurrency",
          "lambda:AddPermission", "lambda:RemovePermission", "lambda:GetPolicy",
          "lambda:TagResource", "lambda:UntagResource", "lambda:ListTags"
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-*"
      },

      # CloudWatch Logs — Lambda log groups
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy",
          "logs:TagLogGroup", "logs:UntagLogGroup",
          "logs:ListTagsForResource", "logs:TagResource", "logs:UntagResource"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-*"
      }
    ]
  })
}
