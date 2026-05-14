output "state_bucket_name" {
  description = "Name of the S3 bucket storing Terraform state"
  value       = aws_s3_bucket.state.id
}

output "deployer_policy_arn" {
  description = "ARN of the scoped deployer IAM policy — attach this to your IAM user after bootstrap"
  value       = aws_iam_policy.deployer.arn
}

output "backend_config" {
  description = "Copy this block into backend.tf in the root directory, then run terraform init"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.state.id}"
        key          = "${var.environment}/terraform.tfstate"
        region       = "${var.aws_region}"
        use_lockfile = true
        encrypt      = true
      }
    }
  EOT
}
