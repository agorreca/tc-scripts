#!/bin/bash

# Determine the directory where main.sh is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all the necessary scripts
source "$SCRIPT_DIR/logging.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/prompts.sh"
source "$SCRIPT_DIR/git_functions.sh"
source "$SCRIPT_DIR/jira_functions.sh"
source "$SCRIPT_DIR/github_functions.sh"
source "$SCRIPT_DIR/google_chat.sh"

# Aliases
alias smartpush="createCommitAndPRs"
# Add other aliases as needed
