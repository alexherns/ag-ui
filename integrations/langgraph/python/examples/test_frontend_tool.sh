#!/bin/bash

# Test script for frontend-defined tool workflow with AG-UI
# This demonstrates the confirmAction tool pattern

set -e

# Configuration
ENDPOINT="http://localhost:8000/agent/tool_based_generative_ui"
THREAD_ID=$(uuidgen)

echo "========================================="
echo "Frontend-Defined Tool Test"
echo "========================================="
echo "Thread ID: $THREAD_ID"
echo ""

# Step 1: Send initial request
echo "Step 1: Sending request for haiku..."
echo "----------------------------------------"

FIRST_RESPONSE=$(curl --silent --request POST \
  --url "$ENDPOINT" \
  --header 'Content-Type: application/json' \
  --header 'Accept: text/event-stream' \
  --data '{
  "threadId": "'$THREAD_ID'",
  "runId": "run-1",
  "state": {},
  "messages": [
    {
      "id": "msg-1",
      "role": "user",
      "content": "Write a haiku about oceans"
    }
  ],
  "tools": [{
    "name": "confirmAction",
    "description": "Ask the user to confirm a specific action before proceeding",
    "parameters": {
      "type": "object",
      "properties": {
        "action": {
          "type": "string",
          "description": "The action that needs user confirmation"
        },
        "importance": {
          "type": "string",
          "enum": ["low", "medium", "high", "critical"],
          "description": "The importance level of the action"
        }
      },
      "required": ["action"]
    }
  }],
  "context": [],
  "forwardedProps": {}
}')

echo "✓ Received response"

# Extract MESSAGES_SNAPSHOT from the response
MESSAGES_SNAPSHOT=$(echo "$FIRST_RESPONSE" | grep 'data: {"type":"MESSAGES_SNAPSHOT"' | sed 's/^data: //')

if [ -z "$MESSAGES_SNAPSHOT" ]; then
  echo "❌ Error: No MESSAGES_SNAPSHOT found in response"
  exit 1
fi

# Extract tool call ID - look for the ID within toolCalls array
TOOL_CALL_ID=$(echo "$MESSAGES_SNAPSHOT" | grep -o '"toolCalls":\[{"id":"[^"]*"' | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOOL_CALL_ID" ]; then
  echo "❌ Error: Could not extract tool call ID"
  echo "Debug: MESSAGES_SNAPSHOT = $MESSAGES_SNAPSHOT"
  exit 1
fi

echo "✓ Agent requested confirmation"
echo "  Tool Call ID: $TOOL_CALL_ID"
echo ""

# Step 2: Send confirmation
echo "Step 2: Sending confirmation..."
echo "----------------------------------------"

SECOND_RESPONSE=$(curl --silent --request POST \
  --url "$ENDPOINT" \
  --header 'Content-Type: application/json' \
  --header 'Accept: text/event-stream' \
  --data '{
  "threadId": "'$THREAD_ID'",
  "runId": "run-2",
  "state": {},
  "messages": [
    {
      "id": "msg-2",
      "role": "tool",
      "toolCallId": "'$TOOL_CALL_ID'",
      "toolName": "confirmAction",
      "content": "confirmed"
    }
  ],
  "tools": [{
    "name": "confirmAction",
    "description": "Ask the user to confirm a specific action before proceeding",
    "parameters": {
      "type": "object",
      "properties": {
        "action": {
          "type": "string",
          "description": "The action that needs user confirmation"
        },
        "importance": {
          "type": "string",
          "enum": ["low", "medium", "high", "critical"],
          "description": "The importance level of the action"
        }
      },
      "required": ["action"]
    }
  }],
  "context": [],
  "forwardedProps": {}
}')

echo "✓ Confirmation sent"
echo ""

# Extract the haiku from MESSAGES_SNAPSHOT (easier and more reliable)
echo "========================================="
echo "Generated Haiku:"
echo "========================================="

FINAL_MESSAGES=$(echo "$SECOND_RESPONSE" | grep 'data: {"type":"MESSAGES_SNAPSHOT"' | sed 's/^data: //')

if [ -z "$FINAL_MESSAGES" ]; then
  echo "❌ Error: Could not find MESSAGES_SNAPSHOT in second response"
  exit 1
fi

# Extract the last assistant message content (the haiku)
HAIKU=$(echo "$FINAL_MESSAGES" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    messages = data.get('messages', [])
    # Find the last assistant message
    for msg in reversed(messages):
        if msg.get('role') == 'assistant' and msg.get('content'):
            print(msg['content'])
            break
except:
    pass
")

if [ -z "$HAIKU" ]; then
  echo "❌ Error: Could not extract haiku"
  echo "Debug: MESSAGES_SNAPSHOT = $FINAL_MESSAGES"
  exit 1
else
  echo "$HAIKU"
fi

echo ""
echo "========================================="
echo "✓ Test completed successfully!"
echo "========================================="
