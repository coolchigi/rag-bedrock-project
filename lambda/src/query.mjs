import {
  BedrockAgentRuntimeClient,
  RetrieveAndGenerateCommand,
} from "@aws-sdk/client-bedrock-agent-runtime";

const client = new BedrockAgentRuntimeClient();
const KNOWLEDGE_BASE_ID = process.env.KNOWLEDGE_BASE_ID;
const MAX_QUERY_LENGTH = 1000;
const MODEL_ARN = process.env.MODEL_ARN;

function log(level, requestId, message) {
  const entry = {
    level,
    timestamp: new Date().toISOString(),
    requestId: requestId || undefined,
    message,
  };
  console.log(JSON.stringify(entry));
}

function hasTimeForRetry(context) {
  if (!context?.getRemainingTimeInMillis) return true;
  return context.getRemainingTimeInMillis() > 15000;
}

function isRetryable(error) {
  const code = error.name || error.code || "";
  return (
    code === "ThrottlingException" ||
    code === "ServiceUnavailableException" ||
    (error.$metadata?.httpStatusCode && error.$metadata.httpStatusCode >= 500)
  );
}

function parseQuery(event) {
  let body = event.body;
  if (typeof body === "string") {
    body = JSON.parse(body);
  }
  return body?.query || null;
}

function buildResponse(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  };
}

export async function handler(event, context) {
  const requestId =
    event?.requestContext?.requestId || context?.awsRequestId || "unknown";
  const start = Date.now();

  log("INFO", requestId, "Request received");

  let query;
  try {
    query = parseQuery(event);
  } catch {
    log("WARN", requestId, "Invalid JSON body");
    return buildResponse(400, { error: "Invalid JSON body" });
  }

  if (!query || typeof query !== "string" || query.trim().length === 0) {
    log("WARN", requestId, "Missing or empty query");
    return buildResponse(400, { error: "query is required and must be a non-empty string" });
  }

  if (query.length > MAX_QUERY_LENGTH) {
    log("WARN", requestId, "Query exceeds max length");
    return buildResponse(400, {
      error: `query must not exceed ${MAX_QUERY_LENGTH} characters`,
    });
  }

  const command = new RetrieveAndGenerateCommand({
    input: { text: query.trim() },
    retrieveAndGenerateConfiguration: {
      type: "KNOWLEDGE_BASE",
      knowledgeBaseConfiguration: {
        knowledgeBaseId: KNOWLEDGE_BASE_ID,
        modelArn: MODEL_ARN,
      },
    },
  });

  let response;
  try {
    response = await client.send(command);
  } catch (error) {
    if (isRetryable(error) && hasTimeForRetry(context)) {
      log("WARN", requestId, "Retrying after transient error");
      try {
        response = await client.send(command);
      } catch (retryError) {
        log("ERROR", requestId, `Retry failed: ${retryError.name}`);
        return buildResponse(503, { error: "Service temporarily unavailable" });
      }
    } else {
      log("ERROR", requestId, `Bedrock error: ${error.name}: ${error.message}`);
      return buildResponse(503, { error: "Service temporarily unavailable" });
    }
  }

  const citations = (response.citations || []).map((c) => ({
    text: c.generatedResponsePart?.textResponsePart?.text || "",
    sources: (c.retrievedReferences || []).map((ref) => ({
      uri: ref.location?.s3Location?.uri || "",
    })),
  }));

  log("INFO", requestId, `Completed in ${Date.now() - start}ms`);

  return buildResponse(200, {
    answer: response.output?.text || "",
    citations,
  });
}
