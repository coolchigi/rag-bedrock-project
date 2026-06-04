output "state_bucket_name" {
  description = "S3 bucket name for Terraform remote state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "S3 bucket ARN for Terraform remote state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "aws_region" {
  description = "AWS region where the state bucket was created"
  value       = var.aws_region
}

output "deployer_policy_arn" {
  description = "ARN of the scoped deployer IAM policy — attach to your IAM user and remove AdministratorAccess"
  value       = aws_iam_policy.deployer.arn
}

output "backend_config" {
  description = "Copy this block into backend.tf in the root directory, then run terraform init"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.terraform_state.id}"
        key          = "${var.environment}/terraform.tfstate"
        region       = "${var.aws_region}"
        use_lockfile = true
        encrypt      = true
      }
    }
  EOT
}
