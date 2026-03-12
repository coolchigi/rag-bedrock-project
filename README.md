# AWS Bedrock RAG Pipeline with Terraform

A reusable Terraform infrastructure for building Retrieval-Augmented Generation (RAG) pipelines using AWS Bedrock Knowledge Bases, OpenSearch Serverless, and S3.

## Architecture

- **S3 Bucket**: Document storage for RAG data sources
- **Amazon Bedrock Knowledge Base**: Manages document ingestion and retrieval
- **OpenSearch Serverless**: Vector database for embeddings
- **IAM Roles**: Secure access between services
- **VPC (Optional)**: Network isolation for Lambda functions

## Quick Start

### 1. Bootstrap (First Time Setup)

```bash
cd bootstrap
terraform init
terraform apply -var="project_name=my-rag" -var="environment=dev"
```

Copy the backend configuration from outputs and update `backend.tf`.

### 2. Deploy RAG Pipeline

```bash
# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

### 3. Upload Documents and Test

```bash
# Upload documents
aws s3 cp ./documents/ s3://YOUR_BUCKET_NAME/ --recursive

# Start ingestion
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id YOUR_KB_ID \
  --data-source-id YOUR_DS_ID

# Test retrieval
aws bedrock-agent-runtime retrieve \
  --knowledge-base-id YOUR_KB_ID \
  --retrieval-query text="Your question here"
```

## Configuration

### Required Variables

```hcl
data_source_bucket_name = "my-documents-bucket"  # S3 bucket for documents
```

### Optional Variables

```hcl
aws_region              = "us-east-1"
project_name            = "bedrock-kb"
environment             = "prod"
embedding_model_id      = "amazon.titan-embed-text-v2:0"
titan_v2_dimensions     = 1024
chunking_strategy       = "FIXED_SIZE"
chunk_max_tokens        = 300
chunk_overlap_percentage = 20
```

## Supported Embedding Models

- `amazon.titan-embed-text-v2:0` (256, 512, or 1024 dimensions)
- `amazon.titan-embed-text-v1` (1536 dimensions)
- `cohere.embed-english-v3` (1024 dimensions)
- `cohere.embed-multilingual-v3` (1024 dimensions)

## Chunking Strategies

- **FIXED_SIZE**: Fixed token chunks with overlap
- **HIERARCHICAL**: Multi-level chunking for better context
- **SEMANTIC**: AI-powered semantic chunking
- **NONE**: No chunking (use original documents)

## Module Structure

```
modules/
├── bootstrap/          # State management setup
├── data-source/        # S3 bucket and Bedrock data source
├── knowledge-base/     # Bedrock Knowledge Base and IAM
├── vector-store/       # OpenSearch Serverless collection
├── iam/               # Lambda execution roles
└── vpc/               # Optional VPC for Lambda isolation
```

## Outputs

- `knowledge_base_id`: For API integration
- `s3_bucket_name`: For document uploads
- `kb_role_arn`: For Lambda functions
- `collection_endpoint`: OpenSearch endpoint
- `deployment_commands`: Next steps

## Cost Optimization

- OpenSearch Serverless: Pay per use
- Bedrock: Pay per API call and token
- S3: Standard storage pricing
- No always-on compute costs

## Security Features

- S3 bucket encryption and public access blocking
- IAM roles with least privilege access
- VPC isolation for Lambda functions
- OpenSearch Serverless network policies

## Customization

### Adding Lambda Functions

```hcl
module "iam" {
  source = "./modules/iam"
  name_prefix = local.name_prefix
}

resource "aws_lambda_function" "rag_query" {
  filename         = "rag_function.zip"
  function_name    = "${local.name_prefix}-rag-query"
  role            = module.iam.lambda_execution_role_arn
  handler         = "index.handler"
  runtime         = "python3.11"
  
  environment {
    variables = {
      KNOWLEDGE_BASE_ID = module.knowledge_base.knowledge_base_id
    }
  }
}
```

### Multi-Environment Setup

```hcl
# dev.tfvars
environment = "dev"
project_name = "my-rag"
data_source_bucket_name = "my-rag-dev-documents"

# prod.tfvars  
environment = "prod"
project_name = "my-rag"
data_source_bucket_name = "my-rag-prod-documents"
```

## Troubleshooting

### Common Issues

1. **IAM Propagation**: Wait 20-30 seconds after role creation
2. **OpenSearch Index**: Ensure proper field mappings
3. **Bedrock Model Access**: Enable model access in Bedrock console
4. **S3 Permissions**: Verify bucket policies for Bedrock access

### Validation Commands

```bash
# Check Knowledge Base status
aws bedrock-agent get-knowledge-base --knowledge-base-id YOUR_KB_ID

# List ingestion jobs
aws bedrock-agent list-ingestion-jobs --knowledge-base-id YOUR_KB_ID

# Test OpenSearch connection
curl -X GET "YOUR_COLLECTION_ENDPOINT/_cluster/health"
```

## Contributing

1. Fork the repository
2. Create feature branch
3. Add/modify modules as needed
4. Test with multiple environments
5. Submit pull request

## License

MIT License - see LICENSE file for details