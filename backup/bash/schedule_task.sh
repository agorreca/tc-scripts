#!/bin/bash

# Source the common functions
source "$TC_SCRIPTS_PATH/bash/common.sh"

# Enable debug mode
set -x

# Check if two arguments are passed
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <TASK_TYPE> <TASK_CONFIGURATION_ID>"
  exit 1
fi

TASK_TYPE=$1
TASK_CONFIGURATION_ID=$2

# Check TASK_TYPE
if [[ "$TASK_TYPE" != "AD_HOC" ]]; then
  echo "Error: TASK_TYPE must be AD_HOC"
  exit 1
fi

# Check TASK_CONFIGURATION_ID is a number
if ! [[ "$TASK_CONFIGURATION_ID" =~ ^[0-9]+$ ]]; then
  echo "Error: TASK_CONFIGURATION_ID must be a number"
  exit 1
fi

# Load WEB token
load_token_web

# URL to get task configurations
TASK_CONFIG_URL="https://api-gateway-dev.appthing.io/api/v1/dashboard/task-configuration"

# Fetch task configurations
make_request GET "$TASK_CONFIG_URL" "{}" WEB

# Read the JSON response from response.txt
TASK_CONFIG_RESPONSE=$(cat response.txt)

# Extract sub_type and task_definition_id using jq
SUB_TYPE=$(echo "$TASK_CONFIG_RESPONSE" | jq -r --arg TYPE "$TASK_TYPE" --arg ID "$TASK_CONFIGURATION_ID" '
  .[$TYPE][] | select(.task_configuration_id == $ID) | .value
')

TASK_DEFINITION_ID=$(echo "$TASK_CONFIG_RESPONSE" | jq -r --arg TYPE "$TASK_TYPE" --arg ID "$TASK_CONFIGURATION_ID" '
  .[$TYPE][] | select(.task_configuration_id == $ID) | .task_definition_ids[0]
')

# Check if sub_type and task_definition_id were found
if [[ -z "$SUB_TYPE" ]] || [[ -z "$TASK_DEFINITION_ID" ]]; then
  echo "Error: Configuration for TASK_CONFIGURATION_ID $TASK_CONFIGURATION_ID not found."
  exit 1
fi

echo "Obtained sub_type: $SUB_TYPE"
echo "Obtained task_definition_id: $TASK_DEFINITION_ID"

# Define time range
SINCE=$(start_of_day)
UNTIL=$(end_of_day)

# Define user and locations
USER_ID=$DEFAULT_USER

# Create JSON payload
DATA=$(cat <<EOF
{
  "user_id": $USER_ID,
  "locations": [$LAB_ID],
  "since": "$SINCE",
  "task_definition_ids": [$TASK_DEFINITION_ID],
  "title": "",
  "description": "",
  "until": "$UNTIL",
  "type": "$TASK_TYPE",
  "sub_type": "$SUB_TYPE"
}
EOF
)

echo "JSON Payload: $DATA"

# Make the POST request to schedule the task
RESPONSE=$(make_request POST "https://api-gateway-dev.appthing.io/api/v1/shared/schedule/tasks" "$DATA" WEB)

if [[ "$RESPONSE" -eq 201 ]]; then
  echo "Task scheduled successfully."
elif [[ "$RESPONSE" -eq 401 ]]; then
  echo "Unauthorized. Refreshing token and retrying..."
  refresh_token_web
  RESPONSE=$(make_request POST "https://api-gateway-dev.appthing.io/api/v1/shared/schedule/tasks" "$DATA" WEB)
  if [[ "$RESPONSE" -eq 201 ]]; then
    echo "Task scheduled successfully after refreshing token."
  else
    echo "Error: Failed to schedule task after refreshing token. Response code: $RESPONSE"
    cat response.txt
    exit 1
  fi
else
  echo "Error: Failed to schedule task. Response code: $RESPONSE"
  cat response.txt
  exit 1
fi
