#!/bin/bash
set -e

# Check if file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <file-or-directory>"
    echo "Example: $0 my-document.pdf"
    echo "Example: $0 ./my-pdfs/"
    exit 1
fi

FILE_OR_DIR="$1"

# Get bucket name from Terraform output
BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null)

if [ -z "$BUCKET_NAME" ]; then
    echo "❌ Error: Could not get S3 bucket name from Terraform output"
    echo "Make sure you have deployed the infrastructure with 'terraform apply'"
    exit 1
fi

echo "Uploading to S3 bucket: $BUCKET_NAME"

if [ -f "$FILE_OR_DIR" ]; then
    echo "Uploading file: $FILE_OR_DIR"
    aws s3 cp "$FILE_OR_DIR" "s3://$BUCKET_NAME/"
    echo "✓ Upload complete"
elif [ -d "$FILE_OR_DIR" ]; then
    echo "Uploading directory: $FILE_OR_DIR"
    aws s3 cp "$FILE_OR_DIR" "s3://$BUCKET_NAME/" --recursive
    echo "✓ Upload complete"
else
    echo "❌ Error: File or directory not found: $FILE_OR_DIR"
    exit 1
fi

echo ""
echo "Next step: Run './scripts/sync-knowledge-base.sh' to sync the knowledge base"
