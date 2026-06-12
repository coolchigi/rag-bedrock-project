<p align="center">
  <h1 align="center">RAG Infrastructure on AWS Bedrock</h1>
  Upload documents to S3, query them in plain English.
</p>

<details open="open">
  <summary><h2 style="display: inline-block">Contents</h2></summary>
  <ol>
    <li><a href="#what-gets-deployed">What gets deployed</a></li>
    <li><a href="#architecture">Architecture</a></li>
    <li><a href="#prerequisites">Prerequisites</a></li>
    <li><a href="#deployment">Deployment</a>
      <ul>
        <li><a href="#step-1---bootstrap-one-time-only">Step 1 - Bootstrap</a></li>
        <li><a href="#step-2---configure-variables">Step 2 - Configure variables</a></li>
        <li><a href="#step-3---deploy">Step 3 - Deploy</a></li>
        <li><a href="#step-4---upload-documents">Step 4 - Upload documents</a></li>
        <li><a href="#step-5---query-your-documents">Step 5 - Query</a></li>
      </ul>
    </li>
    <li><a href="#teardown">Teardown</a></li>
    <li><a href="#module-structure">Module structure</a></li>
    <li><a href="#troubleshooting">Troubleshooting</a></li>
  </ol>
</details>


## What gets deployed
--------------------

| Resource | Purpose |
|---|---|
| S3 bucket | Document storage - upload PDFs and text files here |
| OpenSearch Serverless | Vector database - stores embedded document chunks |
| Bedrock Knowledge Base | Orchestrates chunking, embedding, and indexing |
| Bedrock Data Source | Connects S3 to the Knowledge Base |
| Ingestion Lambda | Triggered on S3 upload - starts a Bedrock ingestion job automatically |
| Query Lambda | Accepts a question, returns an answer grounded in your documents |
| CloudWatch Log Groups | 14-day log retention for both Lambda functions |
| SNS Topic | Operational alerts for Lambda errors |


## Architecture
---------------

```
User uploads PDF
      │
      ▼
   S3 Bucket ──── S3 Event ────▶ Ingestion Lambda
                                       │
                                       ▼
                               Bedrock Ingestion Job
                                       │
                              chunk → embed → index
                                       │
                                       ▼
                              OpenSearch Serverless
                              (vector store)

User sends query
      │
      ▼
 Query Lambda ──▶ Bedrock RetrieveAndGenerate ──▶ OpenSearch (retrieve chunks)
                         │
                         ▼
                   Claude Sonnet 4.5 (generate answer)
                         │
                         ▼
               Answer + source citations
```

S3 uploads trigger ingestion automatically via a Lambda. Queries go through a second Lambda that calls Bedrock's `RetrieveAndGenerate` API, which handles retrieval from OpenSearch and generation via Claude in a single call.


## Prerequisites
----------------

### Tools

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.10
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [aws-vault](https://github.com/99designs/aws-vault)

```bash
brew install awscli terraform aws-vault
```

### AWS account

You need an IAM user with programmatic access (access key + secret key). During the bootstrap step, the user needs `AdministratorAccess`. After bootstrap, you swap to a scoped deployer policy as `AdministratorAccess` is not needed again.

### Bedrock model access

AWS now enables foundation models automatically on first invocation. The Bedrock Model access page has been retired; model access is granted automatically.

### Configure aws-vault

aws-vault stores your credentials in the macOS Keychain instead of a plaintext file.

```bash
# Add your IAM user credentials
aws-vault add YOUR_PROFILE

# Verify - should print your account ID and user ARN
aws-vault exec YOUR_PROFILE --no-session -- aws sts get-caller-identity
```

> **Why `--no-session`?** By default, aws-vault calls `sts:GetSessionToken` to generate a short-lived session token. Certain IAM operations reject these tokens. `--no-session` injects your long-term credentials directly, which works for all operations. Use it on every command in this project.

---

## Deployment
-------------

### Step 1 - Bootstrap (one time only)

The bootstrap creates an S3 bucket for Terraform state (S3 native locking - no DynamoDB needed) and a scoped deployer IAM policy that replaces `AdministratorAccess` after setup.

Before running it, you need `AdministratorAccess` on your IAM user. An IAM user cannot grant itself permissions it doesn't already have, so this has to be done by root or an existing admin - not the user you're bootstrapping.

**Option A - AWS Console (recommended):**
1. Sign in as root or an IAM admin
2. Go to IAM → Users → `YOUR_IAM_USER` → Permissions → Add permissions
3. Choose "Attach policies directly", search for `AdministratorAccess`, and attach it

**Option B - AWS CLI with a separate admin profile:**
```bash
aws-vault exec YOUR_ADMIN_PROFILE --no-session -- aws iam attach-user-policy \
  --user-name YOUR_IAM_USER \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

`YOUR_ADMIN_PROFILE` must be a separate aws-vault profile that already has IAM admin rights.

Run the bootstrap:

```bash
aws-vault exec YOUR_PROFILE --no-session -- \
  terraform -chdir=bootstrap init

aws-vault exec YOUR_PROFILE --no-session -- \
  terraform -chdir=bootstrap apply \
  -var="project_name=my-rag" -var="environment=dev"
```

Type `yes` when prompted. Two outputs matter when it finishes:

**`backend_config`** - copy this block into `backend.tf` in the root directory:

```hcl
terraform {
  backend "s3" {
    bucket       = "my-rag-dev-terraform-state-123456789012"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

**`deployer_policy_arn`** - the ARN you'll use in the next step.

Initialise the root module and migrate any existing local state to S3:

```bash
aws-vault exec YOUR_PROFILE --no-session -- terraform init -migrate-state
```

Type `yes` when prompted to copy existing state.

Now swap to the scoped deployer policy:

```bash
# Attach the deployer policy the bootstrap just created
aws-vault exec YOUR_PROFILE --no-session -- aws iam attach-user-policy \
  --user-name YOUR_IAM_USER \
  --policy-arn YOUR_DEPLOYER_POLICY_ARN

# Remove AdministratorAccess
aws-vault exec YOUR_PROFILE --no-session -- aws iam detach-user-policy \
  --user-name YOUR_IAM_USER \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

Replace `YOUR_DEPLOYER_POLICY_ARN` with the `deployer_policy_arn` value from the bootstrap output.

> **Updating the deployer policy later:** If you hit an `AccessDeniedException` during deploy, the deployer policy is missing a permission. Re-attach `AdministratorAccess` via the console, re-run `terraform -chdir=bootstrap apply` with the same variables, then swap back and remove `AdministratorAccess`. The policy updates in place - no other state is affected.

---

### Step 2 - Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_name         = "my-rag"    # must match what you used in bootstrap
environment          = "dev"
aws_region           = "us-east-1"
embedding_dimensions = 512         # 256 or 512 - half the storage cost vs 1024
```

---

### Step 3 - Deploy

The OpenSearch collection must exist before the rest of the infrastructure can deploy, and the vector index must exist before Bedrock can create the Knowledge Base. This requires a sequenced three-part deploy. It is a one-time setup step and does not affect subsequent deploys.

**3a - Create the OpenSearch collection:**

```bash
aws-vault exec YOUR_PROFILE --no-session -- terraform apply -target=module.opensearch
```

Type `yes` when prompted.

**3b - Set the collection endpoint:**

Once the collection is created, get its endpoint and add it to `terraform.tfvars`:

```bash
aws-vault exec YOUR_PROFILE --no-session -- terraform output collection_endpoint
```

Open `terraform.tfvars` and set:

```hcl
collection_endpoint = "https://YOUR_ENDPOINT.us-east-1.aoss.amazonaws.com"
```

**3c - Deploy everything else:**

From the project root (not the `bootstrap/` directory):

```bash
aws-vault exec YOUR_PROFILE --no-session -- terraform init
```

Then deploy:

```bash
aws-vault exec YOUR_PROFILE --no-session -- terraform apply
```

The `init` is needed once to download the OpenSearch provider. Type `yes` when prompted for the apply. This step takes a few minutes - Bedrock and OpenSearch resources take time to provision.

When it finishes, note the outputs - you will need them in the next steps:

```bash
aws-vault exec YOUR_PROFILE --no-session -- terraform output
```

---

### Step 4 - Upload documents

Copy your PDFs or text files to S3. The local path can be anywhere on your machine:

```bash
BUCKET=$(aws-vault exec YOUR_PROFILE --no-session -- terraform output -raw document_bucket_name)
aws-vault exec YOUR_PROFILE --no-session -- aws s3 cp /path/to/your/documents/ s3://$BUCKET/ --recursive
```

Uploading a file automatically triggers the ingestion Lambda, which starts a Bedrock ingestion job. Ingestion takes 1-5 minutes depending on file count and size.

Check ingestion status:

```bash
KB_ID=$(aws-vault exec YOUR_PROFILE --no-session -- terraform output -raw knowledge_base_id)
DS_ID=$(aws-vault exec YOUR_PROFILE --no-session -- terraform output -raw data_source_id)
aws-vault exec YOUR_PROFILE --no-session -- aws bedrock-agent list-ingestion-jobs \
  --knowledge-base-id $KB_ID \
  --data-source-id $DS_ID \
  --region us-east-1
```

Wait for `"status": "COMPLETE"` before querying. The list shows all historical jobs - check the most recent one by `createdAt`.

```json
{
  "ingestionJobSummaries": [
    {
      "ingestionJobId": "12345678-90ab-cdef-1234-567890abcdef",
      "knowledgeBaseId": "kb-abcdefghij1234567890",
      "dataSourceId": "ds-abcdefghij1234567890",
      "status": "COMPLETE",
      "createdAt": "2024-01-01T12:00:00Z",
      "updatedAt": "2024-01-01T12:05:00Z"
    }
  ]
}
```

---

### Step 5 - Query your documents

```bash
FN=$(aws-vault exec YOUR_PROFILE --no-session -- terraform output -raw query_function_name)
aws-vault exec YOUR_PROFILE --no-session -- aws lambda invoke \
  --function-name $FN \
  --payload '{"body":"{\"query\":\"What are the main topics covered in these documents?\"}","requestContext":{"requestId":"test-1"},"headers":{}}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/response.json && cat /tmp/response.json
```

The response includes the answer and citations pointing to the source document chunks:

```json
{
  "statusCode": 200,
  "headers": { "Content-Type": "application/json" },
  "body": "{\"answer\":\"The documents cover...\",\"citations\":[{\"text\":\"...\",\"sources\":[{\"uri\":\"s3://my-rag-dev-documents/report.pdf\"}]}]}"
}
```

> **Note:** The `body` field is a JSON string. Parse it if you want to work with the answer and citations programmatically.

---

## Teardown
-----------

Destroy all deployed infrastructure:

```bash
aws-vault exec YOUR_PROFILE --no-session -- terraform destroy
```

If the destroy fails with:

```
Error: waiting for Bedrock Agent Data Source delete
unexpected state 'DELETE_UNSUCCESSFUL' ... Unable to delete data from vector store
```

Bedrock is trying to clean up vector data from OpenSearch while OpenSearch itself is being torn down at the same time. Since the whole collection is being destroyed anyway, the cleanup is moot. Set `data_deletion_policy = "RETAIN"` on the data source in `modules/bedrock/main.tf`, then re-run `terraform destroy`.

Then destroy the bootstrap resources. The state bucket is versioned, so you must empty it before it can be deleted:

```bash
# Remove all object versions from the state bucket
BUCKET=$(aws-vault exec YOUR_PROFILE --no-session -- terraform -chdir=bootstrap output -raw state_bucket_name)

aws-vault exec YOUR_PROFILE --no-session -- aws s3api delete-objects \
  --bucket $BUCKET \
  --delete "$(aws-vault exec YOUR_PROFILE --no-session -- \
    aws s3api list-object-versions \
    --bucket $BUCKET \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json)"

# Destroy bootstrap
aws-vault exec YOUR_PROFILE --no-session -- \
  terraform -chdir=bootstrap destroy
```

---

## Module structure
-------------------

```
bootstrap/          one-time state setup (S3 bucket with native locking, deployer policy)
modules/
  storage/          S3 document bucket
  opensearch/       OpenSearch Serverless security policies and collection
  bedrock/          Bedrock Knowledge Base, data source, and KB IAM role
  lambda/           ingestion and query Lambda functions, execution roles, and log groups
lambda/
  src/
    ingest.mjs      S3-triggered handler - starts Bedrock ingestion jobs
    query.mjs       query handler - calls RetrieveAndGenerate, returns answer + citations
  package.json
main.tf             root orchestration - providers, SNS topic, module wiring
variables.tf
outputs.tf
backend.tf          terraform block, S3 backend config, and AWS provider
terraform.tfvars.example
```

---

## Troubleshooting
------------------

### Credentials & connectivity

**`InvalidClientTokenId` on any command**
You ran the command without `--no-session`. Every command in this project requires it: `aws-vault exec YOUR_PROFILE --no-session -- ...`

**`No such host` on any AWS endpoint**
Your machine cannot reach AWS. Check your internet connection and VPN.

---

### Bootstrap & IAM

**`iam:AttachUserPolicy` - not authorized**
An IAM user cannot grant itself permissions it does not already have. The initial `AdministratorAccess` attachment must be done by root or a separate admin account via the AWS Console or a different aws-vault profile. See Step 1.

**`AccessDeniedException` during `terraform apply`**
The deployer policy is missing a permission. To fix: update `bootstrap/main.tf` to add the missing action, re-attach `AdministratorAccess` via the console, re-run `terraform -chdir=bootstrap apply` with the same variables, then swap back to the deployer policy and remove `AdministratorAccess`. See the note at the end of Step 1.

Common permissions that have come up missing during deployment:
- `aoss:TagResource`, `aoss:BatchGetCollection` - OpenSearch collection create/wait
- `sns:ListTagsForResource` - SNS topic tagging
- `logs:ListTagsForResource` - CloudWatch log group tagging
- `s3:CreateBucket` denied despite being in the policy - check that the S3 resource ARN in the policy covers `${environment}-${project_name}-*`, not just `${project_name}-*`

---

### Terraform state

**`Backend configuration changed` on `terraform init`**
Terraform detected the backend changed from local to S3. Use the migrate flag:
```bash
aws-vault exec YOUR_PROFILE --no-session -- terraform init -migrate-state
```

**`ConflictException: A collection with name '...' already exists`**
A previous apply failed partway through - the collection was created in AWS but never saved to Terraform state. Import it instead of recreating:
```bash
aws-vault exec YOUR_PROFILE --no-session -- terraform import \
  module.opensearch.aws_opensearchserverless_collection.vectors \
  YOUR_COLLECTION_ID
```
Find `YOUR_COLLECTION_ID` in the AWS Console under OpenSearch Serverless → Collections, or as the last segment after `collection/` in the ARN from the error output. Then re-run `terraform apply -target=module.opensearch`.

**`Output "collection_endpoint" not found`**
The output exists in `outputs.tf` but is not yet in state because it was added after the initial apply. Refresh state without making changes:
```bash
aws-vault exec YOUR_PROFILE --no-session -- terraform apply -target=module.opensearch -refresh-only
```

---

### OpenSearch

**Index creation returns 403**
The AOSS data access policy has not fully propagated yet - AWS takes up to 60 seconds. Wait a minute and retry.

**`HEAD healthcheck failed: This is usually due to network or permission issues`**
OpenSearch Serverless does not respond to the health ping the standard OpenSearch provider sends on startup. Set `healthcheck = false` in the `provider "opensearch"` block in `backend.tf`.

**`ValidationException: no such index [bedrock-knowledge-base-default-index]`**
Usually a downstream effect of the healthcheck failure above - the index was never created so Bedrock has nothing to connect to. Fix the healthcheck error first, then re-run `terraform apply`.

**Index is destroyed and recreated on every `terraform apply`**
If Terraform shows a destroy/replace for `opensearch_index.bedrock_kb` on every run, the culprit is a type mismatch in the `AMAZON_BEDROCK_METADATA` mapping. The `index` field must be a boolean `false`, not the string `"false"`. In `main.tf`:

```hcl
"AMAZON_BEDROCK_METADATA" = {
  type  = "text"
  index = false   # boolean, not "false"
}
```

This matters because every time Terraform recreates the index, any previously ingested data is wiped and you have to re-ingest.

---

### Ingestion & querying

**`InvalidParameterValueException: Specified ReservedConcurrentExecutions decreases account's UnreservedConcurrentExecution below its minimum value of 50`**
New AWS accounts have a low default concurrency limit. Reserved concurrency on the Lambda functions pushes the unreserved pool below AWS's minimum of 50. This is a dev environment - reserved concurrency is not needed. Remove the `reserved_concurrent_executions` attribute from both Lambda functions in `modules/lambda/main.tf`.

**Query returns 503 - "Service temporarily unavailable"**
The Lambda is catching a Bedrock error and returning 503. Check CloudWatch Logs for the actual error:
```bash
aws-vault exec YOUR_PROFILE --no-session -- aws logs tail \
  /aws/lambda/${environment}-${project_name}-query \
  --since 10m \
  --region us-east-1
```
If the logs show `AccessDeniedException`, check which action is missing. `RetrieveAndGenerate` requires three separate IAM permissions: `bedrock:RetrieveAndGenerate` on the Knowledge Base ARN, `bedrock:Retrieve` on the Knowledge Base ARN, and `bedrock:InvokeModel` on the model ARN. All three are included in `modules/lambda/main.tf` - if you hit this error on a fresh deploy it usually means an earlier version of the file was applied without all three. Run `terraform apply` to reconcile.

**Ingestion job status is `FAILED`**
Check CloudWatch Logs at `/aws/lambda/${environment}-${project_name}-ingest`. Most common cause: unsupported file format. Bedrock supports PDF, plain text, HTML, Word (.docx), and CSV.

**Query returns 400 - "query is required"**
The Lambda expects the query inside a `body` field. Make sure your payload matches the format shown in Step 5.

**Ingestion shows COMPLETE but queries return empty results**
The ingestion job reports `numberOfNewDocumentsIndexed: 2` (or similar) but `bedrock-agent-runtime retrieve` returns `{"retrievalResults": []}`. The most common cause is a timing issue: the ingestion job ran against an old or empty index, and the index was subsequently destroyed and recreated by Terraform. The newly created index is empty even though the job showed success.

To fix:
1. Make sure the index is stable (not being destroyed/recreated on each apply - see the mapping type issue above)
2. Trigger a fresh ingestion job after the index is confirmed stable:
```bash
KB_ID=$(aws-vault exec YOUR_PROFILE --no-session -- terraform output -raw knowledge_base_id)
DS_ID=$(aws-vault exec YOUR_PROFILE --no-session -- terraform output -raw data_source_id)

aws-vault exec YOUR_PROFILE --no-session -- aws bedrock-agent start-ingestion-job \
  --knowledge-base-id $KB_ID \
  --data-source-id $DS_ID \
  --region us-east-1
```
3. Wait for the new job to reach `COMPLETE`, then retry retrieval

**`terraform destroy` fails with `DELETE_UNSUCCESSFUL` on the data source**
See the note in the Teardown section above - set `data_deletion_policy = "RETAIN"` in `modules/bedrock/main.tf` and re-run.

Note: Bedrock does not provide a way to delete ingestion job history. The list will always show all historical jobs - look at the most recent one by `createdAt` to check current status.
