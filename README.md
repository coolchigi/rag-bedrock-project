# AWS Bedrock RAG Pipeline with Terraform

A reusable Terraform infrastructure for building Retrieval-Augmented Generation (RAG) pipelines using AWS Bedrock Knowledge Bases, OpenSearch Serverless, and S3.

## Architecture

- **S3 Bucket**: Document storage for RAG data sources
- **Amazon Bedrock Knowledge Base**: Manages document ingestion and retrieval
- **OpenSearch Serverless**: Vector database for embeddings
- **IAM Roles**: Secure access between services
- **VPC (Optional)**: Network isolation for Lambda functions

## Prerequisites

### AWS Authentication

You need AWS credentials configured before running any Terraform commands. Pick one of the following:

**Option A: AWS CLI (simplest)**

```bash
aws configure
# Enter your Access Key ID, Secret Access Key, region, and output format
```

Terraform will automatically pick up credentials from `~/.aws/credentials`. All commands in this guide can be run as plain `terraform` commands.

**Option B: aws-vault (recommended for security)**

aws-vault encrypts your credentials in your OS keychain instead of storing them in plaintext.

```bash
brew install aws-vault
aws-vault add YOUR_PROFILE
```

Prefix all Terraform commands with `aws-vault exec YOUR_PROFILE --no-session --`. The `--no-session` flag is required because some IAM operations reject the STS session tokens aws-vault generates by default.

```bash
aws-vault exec YOUR_PROFILE --no-session -- terraform apply
```

**Option C: IAM Identity Center (SSO)**

Best option if you're on a team or want browser-based login with no long-lived keys.

```ini
# ~/.aws/config
[profile YOUR_PROFILE]
sso_start_url  = https://your-subdomain.awsapps.com/start
sso_region     = us-east-1
sso_account_id = YOUR_ACCOUNT_ID
sso_role_name  = AdministratorAccess
region         = us-east-1
```

```bash
aws sso login --profile YOUR_PROFILE
AWS_PROFILE=YOUR_PROFILE terraform apply
```

---

## Quick Start

### 1. Bootstrap (First Time Setup)

The bootstrap creates the S3 state bucket, DynamoDB lock table, and a scoped deployer IAM policy. To create these resources, your IAM user needs `AdministratorAccess` for this step. If it doesn't have it, attach it first:

```bash
aws iam attach-user-policy \
  --user-name YOUR_IAM_USER \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

Then run the bootstrap:

```bash
cd bootstrap
terraform init
terraform apply -var="project_name=my-rag" -var="environment=dev"
```

When the apply completes, Terraform prints a `backend_config` output in your terminal. It looks like this:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-rag-dev-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "my-rag-dev-terraform-lock"
    encrypt        = true
  }
}
```

Copy that block, open `backend.tf` in the root directory, uncomment it, and replace the placeholder values with yours. Then run `terraform init` in the root directory to migrate state to S3.

Now swap `AdministratorAccess` for the scoped deployer policy the bootstrap just created:

```bash
aws iam attach-user-policy \
  --user-name YOUR_IAM_USER \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/my-rag-dev-terraform-deployer

aws iam detach-user-policy \
  --user-name YOUR_IAM_USER \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

From this point on, `AdministratorAccess` is no longer needed.

### 2. Deploy RAG Pipeline

```bash
# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
terraform init

# First deploy only - the OpenSearch provider needs the collection endpoint
# to initialize. That endpoint doesn't exist on a fresh deploy, so Terraform
# errors before creating anything. Create the collection first, then run the
# full apply.
terraform apply -target=module.vector_store

# Deploy everything else
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