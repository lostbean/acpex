#!/bin/bash

# Simple ACP test agent that responds to protocol messages
# Uses newline-delimited JSON (ndjson) as per ACP specification

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
      response='{"jsonrpc":"2.0","id":'$id',"result":{"stop_reason":"done","content":"Echo response"}}'
      debug "Sending session/prompt response"
      send_message "$response"
      ;;

    *)
      response='{"jsonrpc":"2.0","id":'$id',"error":{"code":-32601,"message":"Method not found: '$method'"}}'
      debug "Sending error response for unknown method"
      send_message "$response"
      ;;
  esac
done

debug "EOF reached, exiting"
