#!/bin/bash

# Include the common file
source "$TC_SCRIPTS_PATH/bash/common.sh"

# ==============================
# Parameter Validation
# ==============================

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <TASK_CONFIGURATION_ID> <TASK_DEFINITION_ID>"
  echo "TASK_CONFIGURATION_ID: ID from schedule_task.sh"
  echo "TASK_DEFINITION_ID: ID from create_task_definition.sh"
  exit 1
fi

TASK_CONFIGURATION_ID="$1"
TASK_DEFINITION_ID="$2"

if ! [[ "$TASK_CONFIGURATION_ID" =~ ^[0-9]+$ ]]; then
  echo "Error: TASK_CONFIGURATION_ID must be a number."
  exit 1
fi

if ! [[ "$TASK_DEFINITION_ID" =~ ^[0-9]+$ ]]; then
  echo "Error: TASK_DEFINITION_ID must be a number."
  exit 1
fi

# Load the MOBILE token
load_token_mobile

# ==============================
# Generate Current Timestamp
# ==============================

# Define the function to generate ISO 8601 timestamp with milliseconds and timezone
current_timestamp_iso() {
  # Generates timestamp in format: yyyy-MM-ddTHH:mm:ss.000+00:00
  date -u +"%Y-%m-%dT%H:%M:%S.000+00:00"
}

START_DATE=$(current_timestamp_iso)

# ==============================
# Create JSON Payload
# ==============================

DATA=$(cat <<EOF
{
  "task_configurations": [
    {
      "id": $TASK_CONFIGURATION_ID,
      "start_date": "$START_DATE",
      "location_id": $LAB_ID
    }
  ]
}
EOF
)

# ==============================
# Make the Request
# ==============================

RESPONSE=$(make_request "POST" "$START_TASK_URL" "$DATA" "MOBILE")

# ==============================
# Handle the Response
# ==============================

if [[ "$RESPONSE" -eq 401 ]]; then
  refresh_token_mobile "$RESPONSE"
  # Retry the request after refreshing the token
  RESPONSE=$(make_request "POST" "$START_TASK_URL" "$DATA" "MOBILE")
fi

# Check if the response code indicates success (200 OK or 201 Created)
if [[ "$RESPONSE" -ne 200 ]] && [[ "$RESPONSE" -ne 201 ]]; then
  echo "Error: Failed to start task. Response code: $RESPONSE"
  cat response.txt
  exit 1
fi

echo "Task started successfully with Task Configuration ID '$TASK_CONFIGURATION_ID' and Task Definition ID '$TASK_DEFINITION_ID'."
