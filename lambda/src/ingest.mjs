import {
  BedrockAgentClient,
  StartIngestionJobCommand,
} from "@aws-sdk/client-bedrock-agent";

const client = new BedrockAgentClient();
const KNOWLEDGE_BASE_ID = process.env.KNOWLEDGE_BASE_ID;
const DATA_SOURCE_ID = process.env.DATA_SOURCE_ID;

function log(level, requestId, message) {
  const entry = {
    level,
    timestamp: new Date().toISOString(),
    requestId: requestId || undefined,
    message,
  };
  console.log(JSON.stringify(entry));
}

export async function handler(event, context) {
  const requestId = context?.awsRequestId || "unknown";

  const records = event.Records || [];
  log("INFO", requestId, `S3 event received with ${records.length} record(s)`);

  try {
    const command = new StartIngestionJobCommand({
      knowledgeBaseId: KNOWLEDGE_BASE_ID,
      dataSourceId: DATA_SOURCE_ID,
    });

    const response = await client.send(command);
    log("INFO", requestId, `Ingestion job started: ${response.ingestionJob?.ingestionJobId}`);

    return {
      statusCode: 202,
      body: JSON.stringify({
        message: "Ingestion job started",
        jobId: response.ingestionJob?.ingestionJobId,
      }),
    };
  } catch (error) {
    if (error.name === "ConflictException") {
      log("INFO", requestId, "Ingestion job already running — no-op");
      return {
        statusCode: 200,
        body: JSON.stringify({ message: "Ingestion job already in progress" }),
      };
    }

    log("ERROR", requestId, `Failed to start ingestion: ${error.name}`);
    throw error;
  }
}
