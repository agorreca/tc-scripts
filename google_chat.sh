#!/bin/bash

# Source required scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/jira_functions.sh"

function postToGoogleChat {
  local MESSAGE_TYPE="$1"
  local URL_DEVELOP="$2"
  local TITLE="$3"
  local DESCRIPTION="$4"
  local JIRA_URL="$5"
  local TICKET="$6"
  local WEBHOOK_URL
  WEBHOOK_URL="$(git config --get chat.webhook.url)"

  if [ -z "$WEBHOOK_URL" ]; then
    log_error "Google Chat webhook URL is not set."
    return 1
  fi

  local TICKET_TITLE
  TICKET_TITLE=$(get_jira_ticket_title "$TICKET")

  local TICKET_URL="$JIRA_URL/browse/$TICKET"
  local JIRA_LINK="<a href=\"$TICKET_URL\" target=\"_blank\">Jira Ticket</a>"
  local PR_LINK_DEVELOP="<a href=\"$URL_DEVELOP\" target=\"_blank\">Develop Pull Request</a>"
  local PR_TITLE_HTML="<b>PR Title:</b> $TITLE"
  local PR_DESCRIPTION_HTML="<b>PR Description:</b><br>$DESCRIPTION"
  local DRAFT_STATUS="<b>Status:</b> Draft - Awaiting Proofs from Author"
  local NEXT_STEPS="<b>Next Steps:</b><br>1. <i>Author:</i> Collect and attach proofs from the development environment.<br>2. <i>Reviewers:</i> Begin reviewing once proofs are attached."

  # Construct the JSON payload
  local MESSAGE_PAYLOAD
  MESSAGE_PAYLOAD=$(jq -n --arg jira_link "$JIRA_LINK" \
                               --arg pr_link_develop "$PR_LINK_DEVELOP" \
                               --arg pr_title_html "$PR_TITLE_HTML" \
                               --arg pr_description_html "$PR_DESCRIPTION_HTML" \
                               --arg draft_status "$DRAFT_STATUS" \
                               --arg next_steps "$NEXT_STEPS" \
                               --arg ticket_title "$TICKET_TITLE" '{
    "cardsV2": [
      {
        "cardId": "pr-update",
        "card": {
          "header": {
            "title": $ticket_title,
            "subtitle": "New Draft Pull Request Created"
          },
          "sections": [
            {
              "widgets": [
                {
                  "decoratedText": {
                    "icon": {
                      "knownIcon": "DESCRIPTION"
                    },
                    "topLabel": "Jira Ticket",
                    "text": $jira_link
                  }
                },
                {
                  "decoratedText": {
                    "icon": {
                      "knownIcon": "TICKET"
                    },
                    "topLabel": "Develop Pull Request",
                    "text": $pr_link_develop
                  }
                }
              ]
            },
            {
              "widgets": [
                {
                  "textParagraph": {
                    "text": $pr_title_html
                  }
                },
                {
                  "textParagraph": {
                    "text": $pr_description_html
                  }
                }
              ]
            },
            {
              "widgets": [
                {
                  "textParagraph": {
                    "text": $draft_status
                  }
                },
                {
                  "textParagraph": {
                    "text": $next_steps
                  }
                }
              ]
            }
          ]
        }
      }
    ]
  }')

  safe_curl -X POST -H 'Content-Type: application/json' -d "$MESSAGE_PAYLOAD" "$WEBHOOK_URL" > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    log_success "Message sent to Google Chat successfully."
  else
    log_error "Failed to send message to Google Chat."
  fi
}

function sendGoogleChatNotification {
  local MESSAGE="$1"
  local WEBHOOK_URL
  WEBHOOK_URL="$(git config --get chat.webhook.url)"

  if [ -z "$WEBHOOK_URL" ]; then
    log_error "Google Chat webhook URL is not set."
    return 1
  fi

  # Build the message manually without using jq to avoid escaping issues
  local FORMATTED_MESSAGE
  FORMATTED_MESSAGE="{
    \"text\": \"$MESSAGE\"
  }"

  safe_curl -X POST -H 'Content-Type: application/json' -d "$FORMATTED_MESSAGE" "$WEBHOOK_URL" > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    log_success "Message sent to Google Chat successfully."
  else
    log_error "Failed to send message to Google Chat."
  fi
}

# Add other Google Chat functions as needed
