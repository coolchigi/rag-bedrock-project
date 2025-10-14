# Quick Reference Guide

## Common Commands

### Initial Setup

```bash
# 1. Configure your variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Edit and set s3_bucket_name

# 2. Deploy infrastructure
./deploy.sh

# OR manually:
terraform init
terraform plan
terraform apply
```

### Working with Documents

```bash
# Upload a single PDF
./scripts/upload-to-s3.sh mydocument.pdf

# Upload multiple PDFs
./scripts/upload-to-s3.sh ./my-pdfs-folder/

# Direct AWS CLI upload
aws s3 cp document.pdf s3://$(terraform output -raw s3_bucket_name)/
```

### Syncing Knowledge Base

```bash
# Sync after uploading new documents
./scripts/sync-knowledge-base.sh

# Check sync status
aws bedrock-agent list-ingestion-jobs \
  --knowledge-base-id $(terraform output -raw knowledge_base_id) \
  --data-source-id $(terraform output -raw data_source_id)
```

### Querying

```bash
# Using shell script
./scripts/query-knowledge-base.sh "What is this document about?"

# Using Python
python examples/query_kb.py "Summarize the key points"

# Using AWS CLI directly
aws bedrock-agent-runtime retrieve-and-generate \
  --input '{"text":"Your question here"}' \
  --retrieve-and-generate-configuration '{
    "type":"KNOWLEDGE_BASE",
    "knowledgeBaseConfiguration":{
      "knowledgeBaseId":"'$(terraform output -raw knowledge_base_id)'",
      "modelArn":"arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-v2"
    }
  }'
```

### Terraform Management

```bash
# View all outputs
terraform output

# View specific output
terraform output knowledge_base_id

# Update infrastructure
terraform plan
terraform apply

# Destroy all resources
terraform destroy
```

### Monitoring and Debugging

```bash
# Check S3 bucket contents
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/

# Get knowledge base details
aws bedrock-agent get-knowledge-base \
  --knowledge-base-id $(terraform output -raw knowledge_base_id)

# View ingestion job details
aws bedrock-agent get-ingestion-job \
  --knowledge-base-id $(terraform output -raw knowledge_base_id) \
  --data-source-id $(terraform output -raw data_source_id) \
  --ingestion-job-id JOB_ID

# Check OpenSearch collection
aws opensearchserverless get-collection \
  --id $(terraform output -raw opensearch_collection_arn | cut -d'/' -f2)
```

## Environment Variables

```bash
# Set AWS region (optional if configured in terraform.tfvars)
export AWS_REGION=us-east-1

# Set AWS profile (if using multiple profiles)
export AWS_PROFILE=myprofile

# Enable Terraform debug logging
export TF_LOG=DEBUG
```

## File Locations

| File | Purpose |
|------|---------|
| `terraform.tfvars` | Your configuration (DO NOT commit) |
| `main.tf` | Infrastructure definition |
| `variables.tf` | Input variables |
| `outputs.tf` | Output values |
| `.terraform.lock.hcl` | Dependency lock file (commit this) |

## Important ARNs and IDs

Get these from `terraform output`:

```bash
# Knowledge Base ID (needed for queries)
terraform output -raw knowledge_base_id

# S3 Bucket Name (needed for uploads)
terraform output -raw s3_bucket_name

# Data Source ID (needed for syncing)
terraform output -raw data_source_id

# AWS Region
terraform output -raw aws_region
```

## Supported File Types

- ✅ PDF (.pdf)
- ✅ Text (.txt)
- ✅ Markdown (.md)
- ✅ Word (.doc, .docx)
- ✅ Excel (.xls, .xlsx)
- ✅ PowerPoint (.ppt, .pptx)
- ✅ HTML (.html)
- ✅ CSV (.csv)

## Common Error Fixes

| Error | Quick Fix |
|-------|-----------|
| `bucket name already exists` | Change `s3_bucket_name` in terraform.tfvars |
| `AccessDeniedException` | Enable model access in AWS Console → Bedrock |
| `terraform: command not found` | Install Terraform from terraform.io |
| `aws: command not found` | Install AWS CLI |
| `Permission denied` on scripts | Run `chmod +x deploy.sh scripts/*.sh` |

## Cost Estimate

| Service | Approximate Cost |
|---------|------------------|
| OpenSearch Serverless | ~$700/month (4 OCU minimum) |
| S3 Storage | ~$0.023/GB/month |
| Bedrock Embeddings | ~$0.0001 per 1K tokens |
| Bedrock Generation | Varies by model ($0.003-$0.03 per 1K tokens) |

**Tip**: Run `terraform destroy` when not in use to minimize costs!

## URLs and Links

- [AWS Bedrock Console](https://console.aws.amazon.com/bedrock/)
- [S3 Console](https://console.aws.amazon.com/s3/)
- [OpenSearch Serverless Console](https://console.aws.amazon.com/aos/home#opensearch/collections)
- [CloudWatch Logs](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups)

## Getting Help

1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review [AWS Documentation](https://docs.aws.amazon.com/bedrock/)
3. Open a GitHub issue
4. AWS Support (if you have a support plan)

## Backup Checklist

Before running `terraform destroy`:

- [ ] Export your Terraform state: `terraform state pull > backup.tfstate`
- [ ] Download important documents from S3
- [ ] Document your configuration settings
- [ ] Export CloudWatch logs if needed
