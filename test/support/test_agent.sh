#!/bin/bash

# Enhanced ACP test agent that responds to protocol messages
# Uses newline-delimited JSON (ndjson) as per ACP specification
#
# This agent demonstrates:
# - Basic protocol compliance (initialize, session/new, session/prompt)
# - Streaming updates (session/update notifications)
# - Bidirectional communication (fs/read_text_file requests)

# Disable debug output - set to 1 to enable
DEBUG=${DEBUG:-0}

debug() {
  if [ "$DEBUG" = "1" ]; then
    echo "DEBUG: $*" >&2
  fi
}

send_message() {
  local json="$1"
  # Ndjson: just output JSON + newline
  echo "$json"
}

send_notification() {
  local method="$1"
  local params="$2"
  # Notifications have no "id" field
  local json='{"jsonrpc":"2.0","method":"'"$method"'","params":'"$params"'}'
  send_message "$json"
}

send_request() {
  local id="$1"
  local method="$2"
  local params="$3"
  local json='{"jsonrpc":"2.0","id":'$id',"method":"'"$method"'","params":'"$params"'}'
  send_message "$json"
}

# Counter for request IDs when making requests to client
REQUEST_ID_COUNTER=1000

# Read line-delimited JSON messages
while IFS= read -r line; do
  # Skip empty lines
  if [ -z "$line" ]; then
    continue
  fi

  debug "Received: $line"

  # Parse method and id using simple grep/sed
  method=$(echo "$line" | grep -o '"method"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
  id=$(echo "$line" | grep -o '"id"[[:space:]]*:[[:space:]]*[0-9]*' | sed 's/[^0-9]//g')

  debug "Method: $method, ID: $id"

  # Handle different methods
  case "$method" in
    initialize)
      response='{"jsonrpc":"2.0","id":'$id',"result":{"protocol_version":"1.0","capabilities":{"sessions":{"new":true,"load":false}},"agent_info":{"name":"TestAgent","version":"0.1.0"}}}'
      debug "Sending initialize response"
      send_message "$response"
      ;;

    session/new)
      session_id="test-session-$$-$RANDOM"
      response='{"jsonrpc":"2.0","id":'$id',"result":{"session_id":"'$session_id'"}}'
      debug "Sending session/new response with session_id: $session_id"
      send_message "$response"
      ;;

    session/prompt)
      # Extract sessionId from params
      session_id=$(echo "$line" | grep -o '"sessionId"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')

      # Extract prompt text
      prompt_text=$(echo "$line" | grep -o '"text"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
      debug "Prompt text: $prompt_text"

      # Send a session/update notification (streaming update)
      debug "Sending session/update notification"
      update_params='{"sessionId":"'$session_id'","update":{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"Processing your request..."}}}'
      send_notification "session/update" "$update_params"

      # Small delay to simulate processing
      sleep 0.1

      # Check if prompt mentions reading a file
      if echo "$prompt_text" | grep -q "Read the file at"; then
        # Extract file path
        file_path=$(echo "$prompt_text" | sed -n 's/.*Read the file at \([^ ]*\).*/\1/p')
        debug "Detected file read request for: $file_path"

        # Send fs/read_text_file request to client
        request_id=$REQUEST_ID_COUNTER
        REQUEST_ID_COUNTER=$((REQUEST_ID_COUNTER + 1))

        debug "Sending fs/read_text_file request (id: $request_id)"
        request_params='{"path":"'"$file_path"'"}'
        send_request "$request_id" "fs/read_text_file" "$request_params"

        # Wait for response
        while IFS= read -r response_line; do
          debug "Received response: $response_line"

          # Check if this is the response to our request
          response_id=$(echo "$response_line" | grep -o '"id"[[:space:]]*:[[:space:]]*[0-9]*' | sed 's/[^0-9]//g')

          if [ "$response_id" = "$request_id" ]; then
            # Extract file content from result
            file_content=$(echo "$response_line" | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
            debug "Received file content: $file_content"

            # Send final response with file content
            response='{"jsonrpc":"2.0","id":'$id',"result":{"stop_reason":"done","content":"File content: '"$file_content"'"}}'
            debug "Sending session/prompt response with file content"
            send_message "$response"
            break
          fi
        done
      else
        # Regular prompt - just send final response
        response='{"jsonrpc":"2.0","id":'$id',"result":{"stop_reason":"done","content":"Echo response"}}'
        debug "Sending session/prompt response"
        send_message "$response"
      fi
      ;;

    *)
      response='{"jsonrpc":"2.0","id":'$id',"error":{"code":-32601,"message":"Method not found: '$method'"}}'
      debug "Sending error response for unknown method"
      send_message "$response"
      ;;
  esac
done

debug "EOF reached, exiting"
