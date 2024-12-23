#!/bin/bash

# ... [Existing script content above] ...

# ===========================
# Dynamic Branches Fetching
# ===========================

# Function to fetch branch names from open PRs against a specified base branch, sorted by creation date
function fetch_open_pr_branches {
  local BASE_BRANCH="$1"

  # Fetch open PRs against the base branch
  local PRS_JSON
  PRS_JSON=$(get_pull_requests "$BASE_BRANCH")

  # Check if the API call was successful
  if [ -z "$PRS_JSON" ]; then
    log_error "Failed to fetch pull requests for base branch '$BASE_BRANCH'."
    return 1
  fi

  # Extract branch names sorted by creation date (oldest first)
  local BRANCH_LIST
  BRANCH_LIST=$(echo "$PRS_JSON" | jq -r 'sort_by(.created_at) | .[] | .head.ref')

  # Convert the list into an array
  echo "${BRANCH_LIST[@]}"
}

# Main execution flow

# Step 1: Fetch open PR branches against 'develop'
log "Fetching open PRs against 'develop' branch..."
BRANCHES=($(fetch_open_pr_branches "develop"))

# Step 2: Check if there are branches to merge
if [ ${#BRANCHES[@]} -eq 0 ]; then
  log_warning "No open PRs to merge into 'deploy/test'. Exiting."
  exit 0
fi

# Step 3: Proceed to merge branches into 'deploy/test'
merge_to_deploy_test "deploy/test recreation process"

# ... [Rest of the existing script content below] ...
