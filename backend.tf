terraform {
  backend "s3" {
    # Configure after bootstrap: bucket, key, region, dynamodb_table
    # Example:
    # bucket         = "bedrock-kb-terraform-state"
    # key            = "prod/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "bedrock-kb-terraform-lock"
    # encrypt        = true
  }
}
