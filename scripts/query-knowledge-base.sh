#!/bin/bash
set -e

# Check if query is provided
if [ -z "$1" ]; then
    echo "Usage: $0 \"Your question here\""
    echo "Example: $0 \"What is this document about?\""
    exit 1
fi

QUERY="$1"
MODEL_ARN="${2:-arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-v2}"

# Get knowledge base ID from Terraform output
KB_ID=$(terraform output -raw knowledge_base_id 2>/dev/null)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

if [ -z "$KB_ID" ]; then
    echo "❌ Error: Could not get knowledge base ID from Terraform output"
    echo "Make sure you have deployed the infrastructure with 'terraform apply'"
    exit 1
fi

echo "Querying knowledge base..."
echo "Question: $QUERY"
echo "Knowledge Base ID: $KB_ID"
echo "Model: $MODEL_ARN"
echo "Region: $REGION"
echo ""
echo "Response:"
echo "========================================="

# Query the knowledge base
aws bedrock-agent-runtime retrieve-and-generate \
    --region "$REGION" \
    --input "{\"text\":\"$QUERY\"}" \
    --retrieve-and-generate-configuration "{
        \"type\":\"KNOWLEDGE_BASE\",
        \"knowledgeBaseConfiguration\":{
            \"knowledgeBaseId\":\"$KB_ID\",
            \"modelArn\":\"$MODEL_ARN\"
        }
    }" \
    --query 'output.text' \
    --output text

echo ""
echo "========================================="
