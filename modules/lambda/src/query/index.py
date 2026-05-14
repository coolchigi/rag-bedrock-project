import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

KNOWLEDGE_BASE_ID = os.environ["KNOWLEDGE_BASE_ID"]
INFERENCE_MODEL_ID = os.environ.get("INFERENCE_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0")
REGION = os.environ.get("AWS_REGION", "us-east-1")

bedrock_runtime = boto3.client("bedrock-agent-runtime")


def handler(event, context):
    """
    Accepts {"query": "..."} and returns an answer grounded in the
    Knowledge Base documents, with S3 source citations.
    """
    try:
        body = json.loads(event["body"]) if isinstance(event.get("body"), str) else event

        query = body.get("query", "").strip()
        if not query:
            return _response(400, {"error": "Missing 'query' field"})
        if len(query) > 1000:
            return _response(400, {"error": "Query exceeds 1000 characters"})

        logger.info("Query: %.100s", query)

        model_arn = f"arn:aws:bedrock:{REGION}::foundation-model/{INFERENCE_MODEL_ID}"

        result = bedrock_runtime.retrieve_and_generate(
            input={"text": query},
            retrieveAndGenerateConfiguration={
                "type": "KNOWLEDGE_BASE",
                "knowledgeBaseConfiguration": {
                    "knowledgeBaseId": KNOWLEDGE_BASE_ID,
                    "modelArn": model_arn,
                    "retrievalConfiguration": {
                        "vectorSearchConfiguration": {"numberOfResults": 5}
                    },
                },
            },
        )

        answer = result.get("output", {}).get("text", "")

        sources = []
        for citation in result.get("citations", []):
            for ref in citation.get("retrievedReferences", []):
                uri = ref.get("location", {}).get("s3Location", {}).get("uri", "")
                if uri:
                    sources.append(uri)

        return _response(200, {"answer": answer, "sources": list(set(sources))})

    except ClientError as e:
        code = e.response["Error"]["Code"]
        logger.error("Bedrock error %s: %s", code, str(e))
        return _response(502, {"error": f"Bedrock error: {code}"})

    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON"})

    except Exception as e:
        logger.error("Unexpected error: %s", str(e), exc_info=True)
        return _response(500, {"error": "Internal server error"})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
