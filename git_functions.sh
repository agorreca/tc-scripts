#!/bin/bash

# Source required scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/prompts.sh"
source "$SCRIPT_DIR/jira_functions.sh"
source "$SCRIPT_DIR/github_functions.sh"
source "$SCRIPT_DIR/google_chat.sh"

function run_checks {
  skip_tests=false

  while getopts "s" opt; do
    case $opt in
      s)
        skip_tests=true
        ;;
      \?)
        echo "Invalid option: -$OPTARG" >&2
        return 1
        ;;
    esac
  done

  npx tsc -p ./apps/avantor-front-react/tsconfig.app.json --noEmit &&
  nx run avantor-front-react:lint &&
  nx format:write --all
}

function diffToCommitMsg {
  if [ -z "$1" ]; then
    log_error "Please provide a ticket number."
    return 1
  fi

  log "Ensuring ticket prefix..."
  local TICKET
  TICKET=$(ensure_prefix "$1")
  log "Generating diff..."
  local DIFF
  DIFF=$(git diff --staged --unified=2)

  if [ -z "$DIFF" ]; then
    log_warning "No changes staged for commit. Please stage your changes first."
    return 1
  fi

  local PROMPT
  PROMPT=$(echo -e "For ticket $TICKET. $DIFF_TO_COMMIT_MSG_PROMPT\n$COMMIT_MESSAGE_EXAMPLE\n\n---\n\n$DIFF")

  log "Copying commit message prompt to clipboard..."
  echo -e "$PROMPT" | copy_to_clipboard

  log "The commit message prompt has been copied to the clipboard. You can ask an AI to generate the commit message from it."
}

function createCommitAndPRs {
  # Enable strict error handling
  set -e
  set -o pipefail

  # Check if a ticket number is provided
  if [ -z "$1" ]; then
    log_error "Please provide a ticket number."
    return 1
  fi

  # Ensure the ticket has the correct prefix
  log "Ensuring ticket prefix..."
  local TICKET
  TICKET=$(ensure_prefix "$1")

  # Validate that the ticket prefix was successful
  if [ -z "$TICKET" ]; then
    log_error "Failed to ensure ticket prefix for '$1'."
    return 1
  fi

  local BRANCH="feature/$TICKET"
  local JIRA_URL
  JIRA_URL=$(git config --get jira.url)

  # Validate JIRA_URL
  if [ -z "$JIRA_URL" ]; then
    log_error "JIRA URL not configured in git."
    return 1
  fi

  local TICKET_URL="$JIRA_URL/browse/$TICKET"

  # Check if there are changes to commit
  if git diff-index --quiet HEAD --; then
    log_warning "No changes to commit."
    return 1
  fi

  # Stash any uncommitted changes
  log "Stashing changes..."
  git stash save "Stash before creating commit and PRs" || {
    log_error "Failed to stash changes."
    return 1
  }

  # Update the develop branch
  log "Switching to develop branch..."
  git checkout develop || {
    log_error "Failed to checkout develop branch."
    git stash pop
    return 1
  }

  log "Pulling latest changes from develop..."
  git pull origin develop || {
    log_error "Failed to pull latest changes from develop."
    git checkout -
    git stash pop
    return 1
  }

  # Create or switch to the feature branch
  log "Creating or switching to feature branch '$BRANCH'..."
  git checkout -B "$BRANCH" || {
    log_error "Failed to create or switch to branch '$BRANCH'."
    git checkout develop
    git stash pop
    return 1
  }

  # Apply stashed changes
  log "Applying stashed changes..."
  git stash pop || log_warning "No stashed changes to apply."

  # Run checks: type-check, linting, formatting, and tests
  log "Running type check, linting, formatting, and tests..."
  if ! run_checks; then
    log_error "Type check, linting, formatting, or tests failed. Aborting."
    git checkout develop
    return 1
  fi

  # Stage all changes
  log "Staging all changes..."
  git add . || {
    log_error "Failed to stage changes."
    git checkout develop
    return 1
  }

  # Generate commit message
  log "Generating commit message..."
  diffToCommitMsg "$TICKET" || {
    log_error "Failed to generate commit message."
    git checkout develop
    return 1
  }

  # Commit changes
  log "Committing changes..."
  git commit || {
    log_error "Failed to commit changes."
    git checkout develop
    return 1
  }

  # Amend the commit to unify multiple commits into one
  log "Amending commit to unify multiple commits..."
  git commit --amend --no-edit || {
    log_error "Failed to amend commit."
    git checkout develop
    return 1
  }

  # Push the feature branch to remote
  log "Pushing feature branch '$BRANCH' to remote..."
  git push -u origin "$BRANCH" || {
    log_error "Failed to push feature branch '$BRANCH' to remote."
    git checkout develop
    return 1
  }

  # Get the latest commit title and body
  local COMMIT_TITLE
  COMMIT_TITLE=$(git log -1 --pretty=format:%s | sed 's/^:[^ ]* //')

  local COMMIT_BODY
  COMMIT_BODY=$(git log -1 --pretty=format:%b)

  # Replace typographic quotes with straight quotes in the commit title and body
  COMMIT_TITLE=$(echo "$COMMIT_TITLE" | sed "s/[’‘]/'/g; s/[“”]/\"/g")
  COMMIT_BODY=$(echo "$COMMIT_BODY" | sed "s/[’‘]/'/g; s/[“”]/\"/g")

  # Create Pull Request to develop in draft mode
  log "Creating draft Pull Request to develop branch..."

  # Check if a PR already exists for develop
  local EXISTING_PR_DEVELOP
  EXISTING_PR_DEVELOP=$(checkExistingPullRequest "develop" "$BRANCH")

  local PR_URL_DEVELOP
  if [ "$(echo "$EXISTING_PR_DEVELOP" | jq '. | length')" -gt 0 ]; then
    log "An existing Pull Request to develop was found. Using existing PR."
    PR_URL_DEVELOP=$(echo "$EXISTING_PR_DEVELOP" | jq -r '.[0].html_url')
  else
    log "Creating a new draft Pull Request to develop..."

    # Get the Jira ticket title
    local JIRA_TITLE
    JIRA_TITLE=$(get_jira_ticket_title "$TICKET") || {
      log_error "Failed to get Jira ticket title for '$TICKET'."
      git checkout develop
      return 1
    }

    # Construct the PR body
    local PR_BODY
    PR_BODY=$(printf "### Jira Tickets\n\n[%s: %s](%s)\n\n### Commits\n\n- %s\n%s\n\n### Proofs\n\n*Please test in the development environment and gather proofs to attach to this PR.*" \
      "$TICKET" "$JIRA_TITLE" "$TICKET_URL" "$COMMIT_TITLE" "$COMMIT_BODY")

    # Create the Pull Request in draft mode
    PR_URL_DEVELOP=$(createPullRequest "develop" ":test_tube: $COMMIT_TITLE" "$PR_BODY" "$BRANCH" true) || {
      log_error "Failed to create draft Pull Request to develop."
      git checkout develop
      return 1
    }

    log "Draft Pull Request to develop created successfully: $PR_URL_DEVELOP."
  fi

  # Send PR details to Google Chat
  log "Sending Pull Request details to Google Chat..."
  postToGoogleChat "created" "$PR_URL_DEVELOP" "$COMMIT_TITLE" "$COMMIT_BODY" "$JIRA_URL" "$TICKET" || {
    log_warning "Failed to send Pull Request details to Google Chat."
  }

  log_success "Commit and PRs created/updated successfully for $TICKET."

  # Update Jira ticket: transition and assign
  log "Updating Jira ticket '$TICKET'..."
  transitionJiraTicket "$TICKET" || log_warning "Failed to transition Jira ticket '$TICKET'."
  autoassignJiraTicket "$TICKET" || log_warning "Failed to assign Jira ticket '$TICKET'."

  # Add a comment to the Jira ticket
  log "Adding comment to Jira ticket..."
  addJiraComment "$TICKET" "Pull Request created: $PR_URL_DEVELOP" || log_warning "Failed to add comment to Jira ticket."

  # Switch back to the develop branch
  log "Switching back to develop branch..."
  git checkout develop || {
    log_error "Failed to switch back to develop branch."
    return 1
  }

  log_success "Operation completed successfully for ticket '$TICKET'."
}

# Add other Git functions as needed
