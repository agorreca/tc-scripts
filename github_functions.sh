#!/bin/bash

# Source required scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"
source "$SCRIPT_DIR/utils.sh"

function createPullRequest {
  local BASE="$1"
  local TITLE="$2"
  local BODY="$3"
  local HEAD="$4"
  local DRAFT_MODE="${5:-false}"

  local API_KEY
  API_KEY=$(git config --get github.token)
  local REPO
  REPO=$(git config --get remote.origin.url | sed 's/.*:\(.*\)\.git/\1/')
  local ORG
  ORG=$(echo "$REPO" | cut -d '/' -f 1)
  local REPO_NAME
  REPO_NAME=$(echo "$REPO" | cut -d '/' -f 2)

  local PR_DATA
  if [ "$DRAFT_MODE" = true ]; then
    PR_DATA=$(jq -n --arg title "$TITLE" --arg head "$HEAD" --arg base "$BASE" --arg body "$BODY" '{
      title: $title, head: $head, base: $base, body: $body, draft: true
    }')
  else
    PR_DATA=$(jq -n --arg title "$TITLE" --arg head "$HEAD" --arg base "$BASE" --arg body "$BODY" '{
      title: $title, head: $head, base: $base, body: $body
    }')
  fi

  local RESPONSE
  RESPONSE=$(safe_curl -s -H "Authorization: token $API_KEY" -d "$PR_DATA" "https://api.github.com/repos/$ORG/$REPO_NAME/pulls")
  RESPONSE=$(clean_json_response "$RESPONSE")

  local PR_URL
  PR_URL=$(echo "$RESPONSE" | jq -r '.html_url')
  local PR_NUMBER
  PR_NUMBER=$(echo "$RESPONSE" | jq -r '.number')

  if [ -z "$PR_URL" ] || [ "$PR_URL" = "null" ]; then
    log_error "Failed to create pull request: $(echo "$RESPONSE" | jq -r '.message')"
    return 1
  fi

  echo "$PR_URL"
}

function checkExistingPullRequest {
  local BASE="$1"
  local HEAD="$2"

  local API_KEY
  API_KEY=$(git config --get github.token)
  local REPO
  REPO=$(git config --get remote.origin.url | sed 's/.*:\(.*\)\.git/\1/')
  local ORG
  ORG=$(echo "$REPO" | cut -d '/' -f 1)
  local REPO_NAME
  REPO_NAME=$(echo "$REPO" | cut -d '/' -f 2)

  if [ -z "$API_KEY" ]; then
    log_error "GitHub API key not found in git config."
    return 1
  fi

  local RESPONSE
  RESPONSE=$(safe_curl -s -H "Authorization: token $API_KEY" "https://api.github.com/repos/$ORG/$REPO_NAME/pulls?base=$BASE&head=$ORG:$HEAD")

  RESPONSE=$(clean_json_response "$RESPONSE")

  echo "$RESPONSE"
}

# Add other GitHub functions as needed
