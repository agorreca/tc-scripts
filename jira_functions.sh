#!/bin/bash

# Source required scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"
source "$SCRIPT_DIR/utils.sh"

function get_jira_ticket_title {
  local TICKET="$1"
  local API_KEY
  API_KEY=$(git config --get jira.token)
  local JIRA_URL
  JIRA_URL=$(git config --get jira.url)

  local RESPONSE
  RESPONSE=$(safe_curl -s -u "$(git config --get jira.email):$API_KEY" -H "Content-Type: application/json" -X GET "$JIRA_URL/rest/api/2/issue/$TICKET")

  RESPONSE=$(clean_json_response "$RESPONSE")

  local TITLE
  TITLE=$(echo "$RESPONSE" | jq -r '.fields.summary')

  if [ -z "$TITLE" ] || [ "$TITLE" = "null" ]; then
    log_error "Failed to get Jira ticket title."
    return 1
  fi

  echo "$TITLE"
}

function transitionJiraTicket {
  local TICKET="$1"
  local TRANSITION_ID="${2:-21}"  # Default to "In Progress"
  local API_KEY
  API_KEY=$(git config --get jira.token)
  local JIRA_URL
  JIRA_URL=$(git config --get jira.url)
  local USER
  USER=$(git config --get jira.email)

  local TRANSITION_DATA
  TRANSITION_DATA=$(jq -n --arg id "$TRANSITION_ID" '{
    transition: {
      id: $id
    }
  }')

  local HTTP_STATUS
  HTTP_STATUS=$(safe_curl -s -o /dev/null -w '%{http_code}' -u "$USER:$API_KEY" -H "Content-Type: application/json" -d "$TRANSITION_DATA" "$JIRA_URL/rest/api/2/issue/$TICKET/transitions")

  if [ "$HTTP_STATUS" -eq 204 ]; then
    log_success "Ticket $TICKET moved to In Progress state."
  elif [ "$HTTP_STATUS" -eq 409 ]; then
    log_warning "Ticket $TICKET is already in the desired state."
  else
    log_error "Failed to transition ticket. Response code from Jira: $HTTP_STATUS"
  fi
}

function getAccountId {
  local API_KEY
  API_KEY=$(git config --get jira.token)
  local JIRA_URL
  JIRA_URL=$(git config --get jira.url)
  local USER
  USER=$(git config --get jira.email)

  local RESPONSE
  RESPONSE=$(safe_curl -s -u "$USER:$API_KEY" -H "Content-Type: application/json" "$JIRA_URL/rest/api/2/myself")

  RESPONSE=$(clean_json_response "$RESPONSE")

  local ACCOUNT_ID
  ACCOUNT_ID=$(echo "$RESPONSE" | jq -r '.accountId')

  echo "$ACCOUNT_ID"
}

function addJiraComment {
  local TICKET="$1"
  local COMMENT="$2"
  local API_KEY
  API_KEY=$(git config --get jira.token)
  local JIRA_URL
  JIRA_URL=$(git config --get jira.url)
  local USER
  USER=$(git config --get jira.email)

  local COMMENT_DATA
  COMMENT_DATA=$(jq -n --arg body "$COMMENT" '{body: $body}')

  local HTTP_STATUS
  HTTP_STATUS=$(safe_curl -s -o /dev/null -w '%{http_code}' -u "$USER:$API_KEY" -H "Content-Type: application/json" -d "$COMMENT_DATA" "$JIRA_URL/rest/api/2/issue/$TICKET/comment")

  if [ "$HTTP_STATUS" -eq 201 ]; then
    log_success "Comment added to Jira ticket successfully."
  else
    log_error "Failed to add comment to Jira ticket. Response code from Jira: $HTTP_STATUS"
  fi
}

function autoassignJiraTicket {
  local TICKET="$1"
  local API_KEY
  API_KEY=$(git config --get jira.token)
  local JIRA_URL
  JIRA_URL=$(git config --get jira.url)
  local USER
  USER=$(git config --get jira.email)

  local ACCOUNT_ID
  ACCOUNT_ID=$(getAccountId)

  if [ -z "$ACCOUNT_ID" ]; then
    log_error "Failed to get account ID."
    return 1
  fi

  local ASSIGN_DATA
  ASSIGN_DATA=$(jq -n --arg accountId "$ACCOUNT_ID" '{
    accountId: $accountId
  }')

  local HTTP_STATUS
  HTTP_STATUS=$(safe_curl -s -o /dev/null -w '%{http_code}' -X PUT -u "$USER:$API_KEY" -H "Content-Type: application/json" -d "$ASSIGN_DATA" "$JIRA_URL/rest/api/2/issue/$TICKET/assignee")

  if [ "$HTTP_STATUS" -eq 204 ]; then
    log_success "Ticket $TICKET assigned successfully."
  elif [ "$HTTP_STATUS" -eq 409 ]; then
    log_warning "Ticket $TICKET is already assigned."
  else
    log_error "Failed to assign ticket. Response code from Jira: $HTTP_STATUS"
  fi
}

# Add other Jira functions as needed
