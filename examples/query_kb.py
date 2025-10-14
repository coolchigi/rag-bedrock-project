"""
Example Python script to query the Bedrock Knowledge Base.

Prerequisites:
- pip install boto3
- AWS credentials configured
- Terraform infrastructure deployed

Usage:
    python examples/query_kb.py "What is this document about?"
"""

import sys
import json
import boto3


def query_knowledge_base(question, knowledge_base_id, region="us-east-1", 
                        model_arn=None):
    """
    Query the Bedrock Knowledge Base using the retrieve-and-generate API.
    
    Args:
        question: The question to ask
        knowledge_base_id: The ID of the knowledge base
        region: AWS region (default: us-east-1)
        model_arn: Optional model ARN (default: Claude v2)
    
    Returns:
        The response text from the knowledge base
    """
    if model_arn is None:
        model_arn = f"arn:aws:bedrock:{region}::foundation-model/anthropic.claude-v2"
    
    # Initialize the Bedrock Agent Runtime client
    client = boto3.client('bedrock-agent-runtime', region_name=region)
    
    try:
        # Query the knowledge base
        response = client.retrieve_and_generate(
            input={
                'text': question
            },
            retrieveAndGenerateConfiguration={
                'type': 'KNOWLEDGE_BASE',
                'knowledgeBaseConfiguration': {
                    'knowledgeBaseId': knowledge_base_id,
                    'modelArn': model_arn
                }
            }
        )
        
        return response['output']['text']
    
    except Exception as e:
        print(f"Error querying knowledge base: {e}")
        raise


def get_terraform_output(output_name):
    """Get a Terraform output value."""
    import subprocess
    try:
        result = subprocess.run(
            ['terraform', 'output', '-raw', output_name],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None


def main():
    """Main function."""
    if len(sys.argv) < 2:
        print("Usage: python query_kb.py \"Your question here\"")
        print('Example: python query_kb.py "What is this document about?"')
        sys.exit(1)
    
    question = sys.argv[1]
    
    # Get configuration from Terraform outputs
    knowledge_base_id = get_terraform_output('knowledge_base_id')
    region = get_terraform_output('aws_region')
    
    if not knowledge_base_id:
        print("Error: Could not get knowledge_base_id from Terraform output")
        print("Make sure you have deployed the infrastructure with 'terraform apply'")
        sys.exit(1)
    
    if not region:
        region = "us-east-1"
    
    print(f"Querying knowledge base...")
    print(f"Question: {question}")
    print(f"Knowledge Base ID: {knowledge_base_id}")
    print(f"Region: {region}")
    print()
    print("Response:")
    print("=" * 80)
    
    # Query the knowledge base
    response = query_knowledge_base(question, knowledge_base_id, region)
    print(response)
    
    print("=" * 80)


if __name__ == "__main__":
    main()
