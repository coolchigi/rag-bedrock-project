#!/bin/bash
set -e

echo "==================================="
echo "RAG Bedrock Project - Setup Script"
echo "==================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    echo "Visit: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install it first."
    echo "Visit: https://www.terraform.io/downloads"
    exit 1
fi

echo "✓ AWS CLI found"
echo "✓ Terraform found"
echo ""

# Check if terraform.tfvars exists
if [ ! -f terraform.tfvars ]; then
    echo "⚠️  terraform.tfvars not found"
    echo "Creating terraform.tfvars from template..."
    cp terraform.tfvars.example terraform.tfvars
    echo ""
    echo "Please edit terraform.tfvars and update the s3_bucket_name variable"
    echo "with a globally unique bucket name, then run this script again."
    exit 1
fi

# Check if s3_bucket_name is set
if grep -q "your-unique-bucket-name-for-pdfs" terraform.tfvars; then
    echo "⚠️  Please update the s3_bucket_name in terraform.tfvars with a unique value"
    exit 1
fi

echo "Starting Terraform deployment..."
echo ""

# Initialize Terraform
echo "1. Initializing Terraform..."
terraform init

# Validate configuration
echo ""
echo "2. Validating configuration..."
terraform validate

# Plan
echo ""
echo "3. Creating execution plan..."
terraform plan -out=tfplan

# Apply
echo ""
echo "4. Applying configuration..."
echo "You will be asked to confirm. Review the plan carefully."
terraform apply tfplan

# Clean up plan file
rm -f tfplan

echo ""
echo "==================================="
echo "✓ Deployment Complete!"
echo "==================================="
echo ""
echo "Next steps:"
echo "1. Upload PDF documents to the S3 bucket:"
echo "   BUCKET_NAME=\$(terraform output -raw s3_bucket_name)"
echo "   aws s3 cp your-document.pdf s3://\$BUCKET_NAME/"
echo ""
echo "2. Sync the knowledge base data source:"
echo "   ./scripts/sync-knowledge-base.sh"
echo ""
echo "3. Query your knowledge base:"
echo "   ./scripts/query-knowledge-base.sh \"Your question here\""
echo ""
