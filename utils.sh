#!/bin/bash

# Function to parse comma-separated tickets into an array
function parse_tickets {
  IFS=',' read -ra TICKETS <<< "$1"
  echo "${TICKETS[@]}"
}

# Function to clean JSON responses
function clean_json_response {
  echo "$1" | tr -d '\000-\037'
}

# Custom curl function to always clean JSON responses
function safe_curl {
  local RESPONSE
  RESPONSE=$(curl "$@")
  clean_json_response "$RESPONSE"
}

# Function to get the project prefix from git config
function get_project_prefix {
  local PROJECT_KEY
  PROJECT_KEY=$(git config --get jira.project)
  echo "$PROJECT_KEY-"
}

# Function to ensure ticket has the correct prefix
function ensure_prefix {
  local TICKET="$1"
  local PROJECT_PREFIX
  PROJECT_PREFIX=$(get_project_prefix)
  if [[ ! "$TICKET" =~ ^$PROJECT_PREFIX ]]; then
    TICKET="$PROJECT_PREFIX$TICKET"
  fi
  echo "$TICKET"
}

# Function to get clipboard content based on the operating system
function get_clipboard_content {
  if command -v pbpaste &>/dev/null; then
    pbpaste
  elif command -v xclip &>/dev/null; then
    xclip -selection clipboard -o
  elif command -v powershell.exe &>/dev/null; then
    powershell.exe Get-Clipboard
  else
    echo "Could not access clipboard." >&2
    return 1
  fi
}

# Function to copy content to clipboard based on the operating system
function copy_to_clipboard {
  if command -v pbcopy &>/dev/null; then
    pbcopy
  elif command -v xclip &>/dev/null; then
    xclip -selection clipboard
  elif command -v powershell.exe &>/dev/null; then
    clip.exe
  else
    echo "Could not copy to clipboard." >&2
    return 1
  fi
}
