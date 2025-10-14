# Troubleshooting Guide

This guide helps you resolve common issues when deploying and using the RAG Bedrock infrastructure.

## Deployment Issues

### Issue: "Error creating OpenSearch Serverless collection"

**Symptoms:**
```
Error: error creating OpenSearch Serverless Collection: ConflictException: 
Concurrent modification or conflicting operation in progress
```

**Causes:**
- Security policies not created before collection
- Network policies not created before collection

**Solutions:**
1. The Terraform configuration handles this with `depends_on`. Ensure you're using the latest code.
2. Wait 1-2 minutes and retry `terraform apply`
3. Check AWS Console → OpenSearch Service → Serverless → Collections for any stuck operations

### Issue: "S3 bucket name already exists"

**Symptoms:**
```
Error: error creating S3 bucket: BucketAlreadyExists: The requested bucket name is not available
```

**Cause:**
S3 bucket names must be globally unique across all AWS accounts.

**Solution:**
1. Edit `terraform.tfvars`
2. Change `s3_bucket_name` to a unique value (e.g., add your account ID or random string)
3. Run `terraform apply` again

### Issue: "AccessDeniedException when creating Bedrock Knowledge Base"

**Symptoms:**
```
Error: error creating Bedrock Agent Knowledge Base: AccessDeniedException: 
You don't have access to the model
```

**Causes:**
- Bedrock model access not enabled in your account
- Wrong region selected

**Solutions:**
1. Go to AWS Console → Amazon Bedrock → Model access
2. Click "Manage model access"
3. Select the models you need (at minimum: Amazon Titan Embeddings)
4. Submit request and wait for approval (usually instant for Titan models)
5. Run `terraform apply` again

### Issue: "Insufficient IAM permissions"

**Symptoms:**
```
Error: error creating ... UnauthorizedException: User is not authorized to perform...
```

**Cause:**
Your AWS credentials don't have sufficient permissions.

**Solution:**
Ensure your IAM user/role has these permissions:
- `s3:*` (or specific S3 permissions)
- `aoss:*` (OpenSearch Serverless)
- `bedrock:*`
- `iam:*` (for role creation)
- `ec2:DescribeVpcs` (for OpenSearch Serverless)

Minimum policy needed:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "aoss:*",
        "bedrock:*",
        "iam:CreateRole",
        "iam:PutRolePolicy",
        "iam:GetRole",
        "iam:DeleteRole",
        "iam:DeleteRolePolicy"
      ],
      "Resource": "*"
    }
  ]
}
```

### Issue: "Region not supported"

**Symptoms:**
```
Error: Bedrock service not available in region
```

**Cause:**
Not all AWS regions support Bedrock.

**Solution:**
Use a supported region (as of 2024):
- us-east-1 (N. Virginia)
- us-west-2 (Oregon)
- ap-southeast-1 (Singapore)
- ap-northeast-1 (Tokyo)
- eu-central-1 (Frankfurt)

Update `aws_region` in `terraform.tfvars`.

## Syncing Issues

### Issue: "Ingestion job fails"

**Symptoms:**
```
Knowledge base sync failed
```

**Diagnosis:**
Check the ingestion job details:
```bash
aws bedrock-agent get-ingestion-job \
  --knowledge-base-id YOUR_KB_ID \
  --data-source-id YOUR_DS_ID \
  --ingestion-job-id JOB_ID
```

**Common Causes and Solutions:**

1. **No documents in S3 bucket**
   - Verify files are uploaded: `aws s3 ls s3://YOUR_BUCKET/`
   - Upload PDFs: `aws s3 cp document.pdf s3://YOUR_BUCKET/`

2. **Invalid document format**
   - Check file extensions are supported (.pdf, .txt, .md, etc.)
   - Ensure files are not corrupted

3. **IAM permission issues**
   - Verify the Bedrock role can read from S3
   - Check CloudTrail logs for access denied errors

4. **Document too large**
   - Split large PDFs into smaller files
   - Maximum individual file size varies by document type

### Issue: "Sync job stuck in IN_PROGRESS"

**Symptoms:**
Ingestion job doesn't complete after a long time.

**Solutions:**
1. Check if there are many/large documents (may take time)
2. Monitor in AWS Console → Bedrock → Knowledge bases → [Your KB] → Data source
3. If stuck for >1 hour, cancel and retry:
   ```bash
   # There's no direct cancel, but you can start a new sync
   ./scripts/sync-knowledge-base.sh
   ```

## Query Issues

### Issue: "No relevant information found"

**Symptoms:**
```
I don't have enough information to answer that question.
```

**Causes:**
- Documents not synced yet
- Question doesn't match document content
- Embeddings not properly generated

**Solutions:**
1. Verify sync completed: Check AWS Console → Bedrock → Knowledge bases
2. Try a more specific question related to your documents
3. Re-sync the knowledge base: `./scripts/sync-knowledge-base.sh`
4. Check if documents contain relevant information

### Issue: "Query returns incorrect model error"

**Symptoms:**
```
AccessDeniedException: You don't have access to the model with the specified model ID
```

**Solutions:**
1. Enable the model in AWS Console → Bedrock → Model access
2. Update model ARN in your query to one you have access to:
   ```bash
   ./scripts/query-knowledge-base.sh "Question" \
     "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-text-express-v1"
   ```

### Issue: "Throttling errors"

**Symptoms:**
```
ThrottlingException: Rate exceeded
```

**Causes:**
- Too many concurrent requests
- Account service quotas exceeded

**Solutions:**
1. Implement exponential backoff in your application
2. Request quota increase: AWS Console → Service Quotas → Bedrock
3. Reduce request rate

## OpenSearch Issues

### Issue: "Collection not accessible"

**Symptoms:**
```
AccessDeniedException when querying OpenSearch
```

**Solutions:**
1. Verify network policy allows access
2. Check data access policy includes the Bedrock role ARN
3. Wait 5-10 minutes after creation for policies to propagate

### Issue: "Index not found"

**Symptoms:**
Knowledge base can't find the vector index.

**Solutions:**
1. The index is created automatically during first sync
2. Ensure you've run at least one successful ingestion job
3. Verify index name matches configuration in `variables.tf`

## Script Issues

### Issue: "terraform output command not found"

**Symptoms:**
```
./scripts/sync-knowledge-base.sh: line X: terraform: command not found
```

**Solution:**
Install Terraform: https://www.terraform.io/downloads

### Issue: "AWS CLI command not found"

**Symptoms:**
```
./scripts/upload-to-s3.sh: line X: aws: command not found
```

**Solution:**
Install AWS CLI: https://aws.amazon.com/cli/

### Issue: "Permission denied when running scripts"

**Symptoms:**
```
bash: ./deploy.sh: Permission denied
```

**Solution:**
Make scripts executable:
```bash
chmod +x deploy.sh scripts/*.sh
```

## Cost Issues

### Issue: "Unexpected high costs"

**Symptoms:**
AWS bill higher than expected.

**Investigation:**
Check AWS Cost Explorer for breakdown by service.

**Common Cost Drivers:**
1. **OpenSearch Serverless**: ~$700/month minimum (4 OCUs)
   - Each OCU costs ~$0.24/hour
   - Charged hourly, even if not actively used
   
2. **Bedrock API calls**:
   - Embedding generation: ~$0.0001 per 1K tokens
   - Text generation: Varies by model (Claude is more expensive than Titan)
   
3. **S3 storage**: ~$0.023/GB/month

**Solutions:**
1. Destroy resources when not in use: `terraform destroy`
2. Use smaller/cheaper models for testing
3. Implement caching for frequently asked questions
4. Monitor usage with CloudWatch

## Debug Mode

### Enable verbose Terraform output

```bash
export TF_LOG=DEBUG
terraform apply
```

### Enable AWS CLI debug output

```bash
aws bedrock-agent-runtime retrieve-and-generate \
  --debug \
  ... other parameters ...
```

### Check CloudWatch Logs

For detailed error information:
1. Go to AWS Console → CloudWatch → Log groups
2. Look for `/aws/bedrock/knowledgebases/` log groups
3. Search for error messages

## Getting More Help

If you've tried the above solutions and still have issues:

1. **Check AWS Service Health Dashboard**: https://status.aws.amazon.com/
2. **Review AWS Documentation**: 
   - [Bedrock Knowledge Bases](https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base.html)
   - [OpenSearch Serverless](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless.html)
3. **AWS Support**: Open a support case if you have a support plan
4. **GitHub Issues**: Report bugs or ask questions in this repository

## Useful Commands for Debugging

```bash
# Check Terraform state
terraform state list
terraform state show aws_bedrockagent_knowledge_base.main

# View all outputs
terraform output

# Validate configuration
terraform validate

# Check AWS CLI configuration
aws configure list
aws sts get-caller-identity

# List S3 bucket contents
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/

# Check knowledge base status
aws bedrock-agent get-knowledge-base \
  --knowledge-base-id $(terraform output -raw knowledge_base_id)

# List ingestion jobs
aws bedrock-agent list-ingestion-jobs \
  --knowledge-base-id $(terraform output -raw knowledge_base_id) \
  --data-source-id $(terraform output -raw data_source_id)
```
