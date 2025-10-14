# Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Applications                         │
│  (AWS CLI, Python SDK, Custom Apps, Web Interfaces)             │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 │ API Calls
                 ↓
┌─────────────────────────────────────────────────────────────────┐
│              AWS Bedrock Agent Runtime API                       │
│         (retrieve-and-generate / retrieve)                       │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────────────────────────────────┐
│                  AWS Bedrock Knowledge Base                      │
│  - Orchestrates RAG pipeline                                     │
│  - Manages embeddings and retrieval                              │
│  - Coordinates with Foundation Models                            │
└──┬──────────────────────────┬──────────────────────────┬────────┘
   │                          │                          │
   │ Read PDFs                │ Generate Embeddings      │ Query
   ↓                          ↓                          ↓
┌──────────────┐    ┌─────────────────────┐    ┌────────────────┐
│  Amazon S3   │    │   Bedrock Models    │    │   OpenSearch   │
│    Bucket    │    │                     │    │   Serverless   │
│              │    │ - Titan Embeddings  │    │                │
│ - PDF Files  │    │ - Claude / Titan    │    │ - Vector DB    │
│ - Versioned  │    │   for Generation    │    │ - Indexes      │
│ - Encrypted  │    │                     │    │ - Encrypted    │
└──────────────┘    └─────────────────────┘    └────────────────┘
```

## Data Flow

### 1. Document Ingestion Flow

```
PDF Upload → S3 Bucket → Knowledge Base Data Source → Sync Job
                                                          ↓
                                                    Text Extraction
                                                          ↓
                                                      Chunking
                                                          ↓
                                            Generate Embeddings (Bedrock)
                                                          ↓
                                         Store in OpenSearch Serverless
```

### 2. Query Flow

```
User Question → Bedrock Knowledge Base
                        ↓
                Generate Question Embedding
                        ↓
                Vector Search in OpenSearch
                        ↓
                Retrieve Relevant Chunks
                        ↓
                Send to LLM (Claude/Titan) with Context
                        ↓
                Generate Response
                        ↓
                Return to User
```

## Component Details

### S3 Bucket
- **Purpose**: Store source PDF documents
- **Features**:
  - Versioning enabled for document history
  - Server-side encryption (AES-256)
  - Secure access via IAM policies
  - Integration with Bedrock Data Source

### OpenSearch Serverless Collection
- **Purpose**: Vector database for embeddings
- **Type**: VECTORSEARCH collection
- **Features**:
  - Serverless (no infrastructure management)
  - Automatic scaling
  - Built-in encryption
  - Network isolation policies
  - Data access policies

### IAM Roles and Policies
- **Bedrock Knowledge Base Role**:
  - S3 read permissions (GetObject, ListBucket)
  - Bedrock model invocation (InvokeModel)
  - OpenSearch API access (APIAccessAll)
  - Scoped to specific resources with conditions

### Bedrock Knowledge Base
- **Configuration**:
  - Type: VECTOR
  - Embedding Model: Amazon Titan (configurable)
  - Storage: OpenSearch Serverless
  - Index mapping for vector, text, and metadata fields

### Bedrock Data Source
- **Type**: S3
- **Configuration**: Connected to PDF bucket
- **Syncing**: Manual or programmatic sync required after updates

## Security Model

```
┌──────────────────────────────────────────────────────────┐
│                     Security Layers                       │
├──────────────────────────────────────────────────────────┤
│ 1. IAM Policies - Least privilege access                 │
│ 2. S3 Encryption - AES-256 at rest                       │
│ 3. OpenSearch Encryption - AWS-owned keys                │
│ 4. Network Policies - Control access to collections      │
│ 5. Data Access Policies - Fine-grained permissions       │
│ 6. Resource Tagging - For organization and compliance    │
│ 7. Condition Keys - Restrict based on account/ARN        │
└──────────────────────────────────────────────────────────┘
```

## Scalability Considerations

- **OpenSearch Serverless**: Automatically scales based on workload
- **S3**: Unlimited storage capacity
- **Bedrock**: Managed service with automatic scaling
- **Cost**: Primarily driven by:
  - OpenSearch Serverless OCUs (4 OCU minimum)
  - Bedrock API calls (embeddings + generation)
  - S3 storage and requests

## Supported Document Types

While this implementation focuses on PDFs, Bedrock Knowledge Bases support:
- PDF documents
- Text files (.txt)
- Markdown files (.md)
- Microsoft Word (.doc, .docx)
- HTML files
- CSV files
- Microsoft Excel (.xls, .xlsx)
- Microsoft PowerPoint (.ppt, .pptx)

To support other formats, simply upload them to the S3 bucket.

## Embedding Models

The infrastructure supports various embedding models:

| Model | Dimensions | Best For |
|-------|-----------|----------|
| amazon.titan-embed-text-v1 | 1536 | General purpose |
| amazon.titan-embed-text-v2:0 | 1024/256 | Improved quality |
| cohere.embed-english-v3 | 1024 | English text |
| cohere.embed-multilingual-v3 | 1024 | Multiple languages |

## Generation Models

For answering questions, you can use:

- **Claude models** (Anthropic):
  - claude-v2
  - claude-v2:1
  - claude-3-sonnet
  - claude-3-haiku

- **Titan models** (Amazon):
  - amazon.titan-text-express-v1
  - amazon.titan-text-lite-v1

## Limitations and Considerations

1. **OpenSearch Serverless Costs**: Minimum 4 OCUs (~$700/month)
2. **Model Access**: Must request access in AWS Console
3. **Document Size**: Individual file size limits apply
4. **Sync Frequency**: Manual sync required after S3 uploads
5. **Vector Dimension**: Must match embedding model output

## Future Enhancements

Potential additions to this infrastructure:

- [ ] Lambda function for automatic sync on S3 upload
- [ ] API Gateway + Lambda for REST API
- [ ] CloudWatch dashboards for monitoring
- [ ] Step Functions for document processing pipeline
- [ ] DynamoDB for conversation history
- [ ] Cognito for user authentication
- [ ] CloudFront + S3 for web UI
- [ ] SNS notifications for sync completion
