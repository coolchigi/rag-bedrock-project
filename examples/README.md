# Python Examples

This directory contains Python examples for interacting with the Bedrock Knowledge Base.

## Prerequisites

Install the required dependencies:

```bash
pip install boto3
```

## Examples

### query_kb.py

Query the knowledge base with a question.

```bash
python examples/query_kb.py "What is this document about?"
```

### Advanced Usage

You can also import and use the functions in your own Python scripts:

```python
from examples.query_kb import query_knowledge_base

# Query the knowledge base
response = query_knowledge_base(
    question="What are the key points in this document?",
    knowledge_base_id="YOUR_KB_ID",
    region="us-east-1"
)

print(response)
```
