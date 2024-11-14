#!/bin/bash

# Include the common file
source "$TC_SCRIPTS_PATH/bash/common.sh"

# ==============================
# Parameter Validation
# ==============================

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <TASK_TYPE> <TASK_TYPE_ID>"
  echo "TASK_TYPE: AD_HOC, STANDARD, WORKSTREAM"
  echo "TASK_TYPE_ID: Numeric ID for task type (e.g., 1 for AD_HOC, 4 for STANDARD, 7 for WORKSTREAM)"
  exit 1
fi

TASK_TYPE="$1"
TASK_TYPE_ID="$2"

if [[ "$TASK_TYPE" != "AD_HOC" && "$TASK_TYPE" != "STANDARD" && "$TASK_TYPE" != "WORKSTREAM" ]]; then
  echo "Error: TASK_TYPE must be AD_HOC, STANDARD, or WORKSTREAM."
  exit 1
fi

if ! [[ "$TASK_TYPE_ID" =~ ^[0-9]+$ ]]; then
  echo "Error: TASK_TYPE_ID must be a number."
  exit 1
fi

# ==============================
# Step 1: Login to WEB
# ==============================

echo "Logging into WEB platform..."
./login.sh
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to log into WEB platform."
  exit 1
fi

# ==============================
# Step 2: Create Task Definition
# ==============================

echo "Creating Task Definition..."
./create_task_definition.sh "$TASK_TYPE"
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to create task definition."
  exit 1
fi

# Extract TASK_DEFINITION_ID from the response
TASK_DEFINITION_ID=$(jq '.id' response.txt)
echo "Task Definition ID: $TASK_DEFINITION_ID"

# ==============================
# Step 3: Schedule Task
# ==============================

echo "Scheduling Task..."
./schedule_task.sh "$TASK_TYPE" "$TASK_DEFINITION_ID"
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to schedule task."
  exit 1
fi

# Extract TASK_CONFIGURATION_ID from the response
TASK_CONFIGURATION_ID=$(jq '.id' response.txt)
echo "Task Configuration ID: $TASK_CONFIGURATION_ID"

# ==============================
# Step 4: Login to MOBILE
# ==============================

echo "Logging into MOBILE platform..."
./login.sh
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to log into MOBILE platform."
  exit 1
fi

# ==============================
# Step 5: Start Task
# ==============================

echo "Starting Task..."
./start_task.sh "$TASK_CONFIGURATION_ID" "$TASK_DEFINITION_ID"
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to start task."
  exit 1
fi

echo "Task workflow completed successfully."
