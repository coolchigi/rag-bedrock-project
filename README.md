# RAG Bedrock Project - Chat with PDFs

A complete infrastructure-as-code solution for building a Retrieval Augmented Generation (RAG) system using AWS Bedrock Knowledge Bases, S3, and OpenSearch Serverless vector database. This project enables you to create a "chat with PDF" experience using Terraform.

## Architecture

This solution provisions the following AWS resources:

- **S3 Bucket**: Stores PDF documents with versioning and encryption enabled
- **Amazon OpenSearch Serverless**: Vector database for storing document embeddings
- **AWS Bedrock Knowledge Base**: Manages the RAG pipeline and document ingestion
- **IAM Roles & Policies**: Secure access control between services
- **Bedrock Foundation Models**: For embeddings and text generation

## Prerequisites

Before you begin, ensure you have:

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 installed ([Download Terraform](https://www.terraform.io/downloads))
3. **AWS CLI** configured with credentials ([Install AWS CLI](https://aws.amazon.com/cli/))
4. **Bedrock Model Access**: Enable access to Bedrock foundation models in your AWS account
   - Go to AWS Console → Bedrock → Model access
   - Request access to the embedding model you plan to use (e.g., Amazon Titan Embeddings)
   - Request access to a chat model (e.g., Claude or Titan Text)

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd rag-bedrock-project
```

### 2. Configure Variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update the following required variables:

```hcl
aws_region      = "us-east-1"
s3_bucket_name  = "your-unique-bucket-name-for-pdfs"  # Must be globally unique
project_name    = "rag-bedrock"
environment     = "dev"
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Preview Changes

```bash
terraform plan
```

### 5. Deploy Infrastructure

```bash
terraform apply
```

Review the planned changes and type `yes` to confirm.

### 6. Upload PDF Documents

After deployment, upload your PDF documents to the S3 bucket:

```bash
# Get the bucket name from Terraform output
BUCKET_NAME=$(terraform output -raw s3_bucket_name)

# Upload PDFs
aws s3 cp your-document.pdf s3://$BUCKET_NAME/
aws s3 cp path/to/pdfs/ s3://$BUCKET_NAME/ --recursive
```

### 7. Sync Knowledge Base

After uploading documents, you need to sync the knowledge base data source:

```bash
# Get the knowledge base and data source IDs
KB_ID=$(terraform output -raw knowledge_base_id)
DS_ID=$(terraform output -raw data_source_id)

# Start ingestion job
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id $KB_ID \
  --data-source-id $DS_ID
```

## Using the Knowledge Base

### Query via AWS CLI

You can query the knowledge base using the AWS CLI:

```bash
KB_ID=$(terraform output -raw knowledge_base_id)

aws bedrock-agent-runtime retrieve-and-generate \
  --input '{"text":"What is this document about?"}' \
  --retrieve-and-generate-configuration '{
    "type":"KNOWLEDGE_BASE",
    "knowledgeBaseConfiguration":{
      "knowledgeBaseId":"'$KB_ID'",
      "modelArn":"arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-v2"
    }
  }'
```

### Query via AWS SDK (Python Example)

```python
import boto3
import json

# Initialize the Bedrock Agent Runtime client
bedrock_agent_runtime = boto3.client('bedrock-agent-runtime', region_name='us-east-1')

# Your knowledge base ID (from Terraform output)
knowledge_base_id = "YOUR_KB_ID"

# Query the knowledge base
response = bedrock_agent_runtime.retrieve_and_generate(
    input={
        'text': 'What is this document about?'
    },
    retrieveAndGenerateConfiguration={
        'type': 'KNOWLEDGE_BASE',
        'knowledgeBaseConfiguration': {
            'knowledgeBaseId': knowledge_base_id,
            'modelArn': 'arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-v2'
        }
    }
)

print(json.dumps(response, indent=2))
```

## Configuration

### Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region for deployment | `us-east-1` | No |
| `project_name` | Prefix for resource names | `rag-bedrock` | No |
| `environment` | Environment name | `dev` | No |
| `s3_bucket_name` | S3 bucket name for PDFs | - | **Yes** |
| `embedding_model_id` | Bedrock embedding model | `amazon.titan-embed-text-v1` | No |
| `vector_index_name` | OpenSearch index name | `bedrock-knowledge-base-index` | No |

### Available Embedding Models

- `amazon.titan-embed-text-v1` - Amazon Titan Embeddings G1 - Text
- `amazon.titan-embed-text-v2:0` - Amazon Titan Embeddings G1 - Text v2
- `cohere.embed-english-v3` - Cohere Embed English
- `cohere.embed-multilingual-v3` - Cohere Embed Multilingual

## Outputs

After deployment, Terraform provides the following outputs:

- `s3_bucket_name` - S3 bucket name for PDFs
- `s3_bucket_arn` - S3 bucket ARN
- `opensearch_collection_endpoint` - OpenSearch Serverless endpoint
- `knowledge_base_id` - Bedrock Knowledge Base ID
- `knowledge_base_arn` - Bedrock Knowledge Base ARN
- `data_source_id` - Data source ID
- `bedrock_kb_role_arn` - IAM role ARN

View outputs with:

```bash
terraform output
```

## Cost Considerations

This infrastructure will incur AWS costs:

- **OpenSearch Serverless**: ~$700/month for 4 OCUs (minimum)
- **S3 Storage**: ~$0.023/GB per month
- **Bedrock**: Pay per API call
  - Embeddings: ~$0.0001 per 1K tokens
  - Text generation: Varies by model

Consider using `terraform destroy` when not in use to minimize costs.

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will permanently delete all resources including the S3 bucket and its contents.

## Troubleshooting

### Issue: "AccessDeniedException" when creating Knowledge Base

**Solution**: Ensure you have requested access to Bedrock models in the AWS Console under Bedrock → Model access.

### Issue: S3 bucket name already exists

**Solution**: S3 bucket names must be globally unique. Choose a different name in `terraform.tfvars`.

### Issue: OpenSearch collection creation fails

**Solution**: Ensure the encryption and network policies are created first. The Terraform configuration handles this with `depends_on`.

### Issue: Knowledge Base sync fails

**Solution**: 
- Verify PDFs are uploaded to the S3 bucket
- Check IAM role has correct permissions
- Ensure the data source is properly configured

## Security Best Practices

1. **Never commit** `terraform.tfvars` or `*.tfstate` files to version control
2. Enable **MFA** on your AWS account
3. Use **least privilege** IAM policies
4. Enable **CloudTrail** logging for audit trails
5. Review **OpenSearch network policies** for production use
6. Consider using **AWS Secrets Manager** for sensitive configuration

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License.

## Resources

- [AWS Bedrock Knowledge Bases Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base.html)
- [Amazon OpenSearch Serverless](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Bedrock Models](https://docs.aws.amazon.com/bedrock/latest/userguide/models-supported.html)