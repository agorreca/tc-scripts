#!/bin/bash

# Include the common file
source "$TC_SCRIPTS_PATH/bash/common.sh"

# ==============================
# Parameter Validation
# ==============================

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <TASK_TYPE>"
  echo "TASK_TYPE: AD_HOC, STANDARD, WORKSTREAM"
  exit 1
fi

TASK_TYPE="$1"

if [[ "$TASK_TYPE" != "AD_HOC" && "$TASK_TYPE" != "STANDARD" && "$TASK_TYPE" != "WORKSTREAM" ]]; then
  echo "Error: TASK_TYPE must be AD_HOC, STANDARD, or WORKSTREAM."
  exit 1
fi

# Load the WEB token
load_token_web

# Get user name and timestamp
USER_NAME=$(git config --get user.name)
TIMESTAMP=$(date +%Y%m%d%H%M%S)
LABEL="${USER_NAME} ${TASK_TYPE} ${TIMESTAMP}"

# Convert LOCATIONS array to JSON
LOCATIONS_JSON=$(array_to_json "${LOCATIONS[@]}")

# Make the request
RESPONSE=$(curl -s -o response.txt -w "%{http_code}" -X POST "$CREATE_TASK_DEFINITION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_WEB" \
  --data @- <<EOF
{
  "label": "$LABEL",
  "type": "$TASK_TYPE",
  "icon": "",
  "active": true,
  "frequency": "ONCE_DAILY_AM",
  "priority": 7,
  "expertise": "Standard",
  "interdependent": true,
  "floors": [
    {
      "floor_id": $FLOOR_ID,
      "locations": $LOCATIONS_JSON,
      "default_user": $DEFAULT_USER,
      "completion_time_in_minutes": 20
    }
  ],
  "steps": [
    {
      "order": 1,
      "process": "",
      "risk_assessment": "",
      "files": []
    }
  ],
  "equipment": []
}
EOF
)

# Handle the response
if [[ "$RESPONSE" -eq 401 ]]; then
  refresh_token_web
  # Retry the request after refreshing the token
  RESPONSE=$(curl -s -o response.txt -w "%{http_code}" -X POST "$CREATE_TASK_DEFINITION_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN_WEB" \
    --data @- <<EOF
{
  "label": "$LABEL",
  "type": "$TASK_TYPE",
  "icon": "",
  "active": true,
  "frequency": "ONCE_DAILY_AM",
  "priority": 7,
  "expertise": "Standard",
  "interdependent": true,
  "floors": [
    {
      "floor_id": $FLOOR_ID,
      "locations": $LOCATIONS_JSON,
      "default_user": $DEFAULT_USER,
      "completion_time_in_minutes": 20
    }
  ],
  "steps": [
    {
      "order": 1,
      "process": "",
      "risk_assessment": "",
      "files": []
    }
  ],
  "equipment": []
}
EOF
)
fi

if [[ "$RESPONSE" -ne 201 ]]; then
  echo "Error: Failed to create task definition. Response code: $RESPONSE"
  cat response.txt
  exit 1
fi

# Extract the task_definition_id from the response
TASK_DEFINITION_ID=$(jq '.id' response.txt)
echo "Task definition '$LABEL' created successfully with ID $TASK_DEFINITION_ID."
