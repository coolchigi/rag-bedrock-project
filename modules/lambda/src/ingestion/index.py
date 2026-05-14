import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

KNOWLEDGE_BASE_ID = os.environ["KNOWLEDGE_BASE_ID"]
DATA_SOURCE_ID = os.environ["DATA_SOURCE_ID"]

bedrock_agent = boto3.client("bedrock-agent")


def handler(event, context):
    """
    Triggered by S3 ObjectCreated events.
    Starts a Bedrock ingestion job so the uploaded document is chunked,
    embedded, and indexed into OpenSearch.
    """
    logger.info("S3 event: %s", json.dumps(event))

    try:
        response = bedrock_agent.start_ingestion_job(
            knowledgeBaseId=KNOWLEDGE_BASE_ID,
            dataSourceId=DATA_SOURCE_ID,
        )

        job = response["ingestionJob"]
        logger.info("Started ingestion job %s — status: %s", job["ingestionJobId"], job["status"])

        return {
            "jobId": job["ingestionJobId"],
            "status": job["status"],
        }

    except ClientError as e:
        logger.error("Failed to start ingestion job: %s", str(e))
        raise
