terraform {
  required_version = ">= 1.5.0"

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

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-${var.environment}-terraform-state-${data.aws_caller_identity.current.account_id}"

  force_destroy = false

  object_lock_enabled = true
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_object_lock_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 30
    }
  }

  depends_on = [aws_s3_bucket_versioning.terraform_state]
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "deployer" {
  name        = "${var.project_name}-${var.environment}-terraform-deployer"
  description = "Scoped policy for Terraform deployments of the ${var.project_name} project. Attach after bootstrap; replace AdministratorAccess."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3State"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:ListBucket", "s3:GetBucketVersioning",
          "s3:GetBucketPolicy", "s3:PutBucketPolicy",
          "s3:GetEncryptionConfiguration", "s3:PutEncryptionConfiguration",
          "s3:GetPublicAccessBlock", "s3:PutPublicAccessBlock",
          "s3:PutBucketVersioning", "s3:GetBucketNotification",
          "s3:PutBucketNotification", "s3:CreateBucket", "s3:DeleteBucket",
          "s3:DeleteObjectVersion", "s3:ListBucketVersions"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::${var.project_name}-*/*",
          "arn:aws:s3:::${var.environment}-${var.project_name}-*",
          "arn:aws:s3:::${var.environment}-${var.project_name}-*/*"
        ]
      },
      {
        Sid    = "IAM"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
          "iam:PassRole", "iam:TagRole", "iam:UntagRole",
          "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy",
          "iam:GetPolicyVersion", "iam:ListPolicyVersions",
          "iam:AttachUserPolicy", "iam:DetachUserPolicy"
        ]
        Resource = "*"
      },
      {
        Sid    = "Lambda"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction", "lambda:DeleteFunction", "lambda:GetFunction",
          "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration",
          "lambda:AddPermission", "lambda:RemovePermission", "lambda:GetPolicy",
          "lambda:PutFunctionEventInvokeConfig", "lambda:GetFunctionEventInvokeConfig",
          "lambda:ListVersionsByFunction", "lambda:TagResource", "lambda:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "OpenSearch"
        Effect = "Allow"
        Action = [
          "aoss:CreateCollection", "aoss:DeleteCollection", "aoss:GetCollection",
          "aoss:BatchGetCollection", "aoss:ListCollections", "aoss:UpdateCollection",
          "aoss:CreateSecurityPolicy", "aoss:DeleteSecurityPolicy", "aoss:GetSecurityPolicy",
          "aoss:ListSecurityPolicies", "aoss:UpdateSecurityPolicy",
          "aoss:CreateAccessPolicy", "aoss:DeleteAccessPolicy", "aoss:GetAccessPolicy",
          "aoss:ListAccessPolicies", "aoss:UpdateAccessPolicy",
          "aoss:GetAccountSettings", "aoss:UpdateAccountSettings",
          "aoss:TagResource", "aoss:UntagResource", "aoss:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "Bedrock"
        Effect = "Allow"
        Action = [
          "bedrock:CreateKnowledgeBase", "bedrock:DeleteKnowledgeBase", "bedrock:GetKnowledgeBase",
          "bedrock:UpdateKnowledgeBase", "bedrock:ListKnowledgeBases",
          "bedrock:CreateDataSource", "bedrock:DeleteDataSource", "bedrock:GetDataSource",
          "bedrock:UpdateDataSource", "bedrock:ListDataSources",
          "bedrock:TagResource", "bedrock:UntagResource", "bedrock:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatch"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy",
          "logs:TagLogGroup", "logs:UntagLogGroup", "logs:ListTagsLogGroup",
          "logs:TagResource", "logs:UntagResource", "logs:ListTagsForResource",
          "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms", "cloudwatch:TagResource", "cloudwatch:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "SNS"
        Effect = "Allow"
        Action = [
          "sns:CreateTopic", "sns:DeleteTopic", "sns:GetTopicAttributes",
          "sns:SetTopicAttributes", "sns:ListTopics",
          "sns:TagResource", "sns:UntagResource", "sns:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid      = "STS"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
}
