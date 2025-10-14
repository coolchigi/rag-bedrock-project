#!/bin/bash
set -e

echo "Syncing Bedrock Knowledge Base..."

# Get knowledge base and data source IDs from Terraform output
KB_ID=$(terraform output -raw knowledge_base_id 2>/dev/null)
DS_ID=$(terraform output -raw data_source_id 2>/dev/null)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

if [ -z "$KB_ID" ] || [ -z "$DS_ID" ]; then
    echo "❌ Error: Could not get knowledge base or data source ID from Terraform output"
    echo "Make sure you have deployed the infrastructure with 'terraform apply'"
    exit 1
fi

echo "Knowledge Base ID: $KB_ID"
echo "Data Source ID: $DS_ID"
echo "Region: $REGION"
echo ""

# Start ingestion job
echo "Starting ingestion job..."
JOB_ID=$(aws bedrock-agent start-ingestion-job \
    --knowledge-base-id "$KB_ID" \
    --data-source-id "$DS_ID" \
    --region "$REGION" \
    --query 'ingestionJob.ingestionJobId' \
    --output text)

if [ -z "$JOB_ID" ]; then
    echo "❌ Error: Failed to start ingestion job"
    exit 1
fi

echo "✓ Ingestion job started with ID: $JOB_ID"
echo ""
echo "Monitoring job status..."

# Poll for job completion
while true; do
    STATUS=$(aws bedrock-agent get-ingestion-job \
        --knowledge-base-id "$KB_ID" \
        --data-source-id "$DS_ID" \
        --ingestion-job-id "$JOB_ID" \
        --region "$REGION" \
        --query 'ingestionJob.status' \
        --output text)
    
    echo "Current status: $STATUS"
    
    if [ "$STATUS" = "COMPLETE" ]; then
        echo ""
        echo "✓ Knowledge base sync completed successfully!"
        break
    elif [ "$STATUS" = "FAILED" ]; then
        echo ""
        echo "❌ Knowledge base sync failed"
        aws bedrock-agent get-ingestion-job \
            --knowledge-base-id "$KB_ID" \
            --data-source-id "$DS_ID" \
            --ingestion-job-id "$JOB_ID" \
            --region "$REGION"
        exit 1
    fi
    
    sleep 10
done
