# Define the combined prompt
COMBINED_PROMPT="Based on the provided diff, you will first create a title and a brief description for a subtask. Then, you will generate a commit message following the conventional commit format. Ensure the subtask is clear and aligns with project goals, and that the commit message includes an appropriate type (e.g., feat, fix, docs), a concise description, and any relevant details or emojis.

Given the following diff, perform these tasks and return the results in JSON format with the properties 'subtask_title', 'subtask_description', and 'commit_message'. Do not include code block delimiters (triple backticks) in the response.

1. Generate a title and brief description for a new task. The title should be in sentence case, and the description should be a single paragraph without mentioning the diff explicitly. Avoid using single or double quotes.

2. Generate a conventional commit message with type, scope, description, and body. The title should follow the format '<emoji> <type>(<ticket key>): <description>' or ':rotating_light: <type>(<ticket key>)!: <description>' for breaking changes. Write it in simple English.
Use these emojis based on the commit type:
- feat: :sparkles:
- fix: :bug:
- docs: :books:
- style: :gem:
- refactor: :hammer:
- perf: :rocket:
- test: :white_check_mark:
- build: :package:
- ci: :construction_worker:
- chore: :wrench:
- breaking changes: :rotating_light:
(The breaking changes emoji has priority and adds a ! symbol before the colon)

Return the result in this JSON format:
{
  \"subtask_title\": \"<title_of_the_subtask>\",
  \"subtask_description\": \"<description_of_the_subtask>\",
  \"commit_message\": \"<conventional_commit_message>\"
}

Example for commit message:

:sparkles: feat(ATM-120): complete WorkstreamStatus component and add new status icons

- Finalized WorkstreamStatus component
- Implemented detailed view for each workstream
- Added new SVG icons for various statuses:
  - completed
  - reported
- Improved layout and usability of TeamInfo component
- Removed an unused import from the Snackbar component

---

"

# Function to call the OpenAI API
function call_openai_api {
  local prompt="$1"
  local api_key="$2"
  # Prepare JSON payload and make API call
  local response=$(jq -n --arg model "gpt-3.5-turbo" \
                        --arg prompt "$prompt" \
                        --arg temperature "0.2" \
                        '{
                          model: $model,
                          messages: [
                            {role: "system", content: "You are a project manager and software engineer with expertise in breaking down tasks and writing conventional commit messages."},
                            {role: "user", content: $prompt}
                          ],
                          temperature: ($temperature | tonumber)
                        }' | curl -s -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
                          -d @-)
  echo "$response"
}

# Function to create a subtask and push changes
function createAndPushTask {
  if [ -z "$1" ]; then
    log_error "Please provide a parent ticket number."
    return 1
  fi

  log "Ensuring ticket prefix..."
  local PARENT_TICKET
  PARENT_TICKET=$(ensure_prefix "$1")
  if [ $? -ne 0 ]; then
    log_error "Failed to ensure ticket prefix."
    return 1
  fi

  local BRANCH="feature/$PARENT_TICKET"
  local JIRA_URL
  JIRA_URL=$(git config --get jira.url)
  local TICKET_URL="$JIRA_URL/browse/$PARENT_TICKET"

  log "Stashing changes..."
  git stash
  if [ $? -ne 0 ]; then
    log_error "Failed to stash changes."
    return 1
  fi

  log "Updating develop branch..."
  git checkout develop
  git pull origin develop
  if [ $? -ne 0 ]; then
    log_error "Failed to update develop branch."
    return 1
  fi

  log "Popping stashed changes..."
  git stash pop
  if [ $? -ne 0 ]; then
    log_error "Failed to pop stashed changes."
    return 1
  fi

  log "Running type check, linting, formatting, and tests..."
  if ! run_checks; then
    log_error "Type check, linting, formatting, or tests failed. Aborting."
    return 1
  fi

  log "Staging changes..."
  git add .
  if [ $? -ne 0 ]; then
    log_error "Failed to stage changes."
    return 1
  fi

  log "Generating diff..."
  local DIFF
  DIFF=$(git diff --staged)
  if [ $? -ne 0 ]; then
    log_error "Failed to generate diff."
    return 1
  fi

  if [ -z "$DIFF" ]; then
    log_warning "No changes detected. Please make some changes before creating a subtask."
    return 1
  fi

  local COMBINED_PROMPT_WITH_DIFF
  COMBINED_PROMPT_WITH_DIFF="${COMBINED_PROMPT}${DIFF}"
  if [ $? -ne 0 ]; then
    log_error "Failed to prepare the combined prompt."
    return 1
  fi

  log "Calling OpenAI API to generate task and commit message..."
  local OPENAI_API_KEY
  OPENAI_API_KEY=$(git config --get openai.key)
  if [ -z "$OPENAI_API_KEY" ]; then
    log_error "OpenAI API key not found."
    return 1
  fi

  local OPENAI_RESPONSE
  OPENAI_RESPONSE=$(call_openai_api "$COMBINED_PROMPT_WITH_DIFF" "$OPENAI_API_KEY")
  if echo "$OPENAI_RESPONSE" | jq -e .error > /dev/null; then
    log_error "OpenAI API error: $(echo "$OPENAI_RESPONSE" | jq -r .error.message)"
    return 1
  fi

  log "Printing OpenAI response..."
  echo "$OPENAI_RESPONSE"

  log "Parsing OpenAI response..."
  local content=$(echo "$OPENAI_RESPONSE" | jq -r '.choices[0].message.content | fromjson')
  local SUBTASK_TITLE=$(echo "$content" | jq -r '.subtask_title')
  local SUBTASK_DESCRIPTION=$(echo "$content" | jq -r '.subtask_description')
  local COMMIT_MESSAGE=$(echo "$content" | jq -r '.commit_message')

  log "Creating subtask in Jira..."
  local PROJECT_KEY
  PROJECT_KEY=$(echo "$PARENT_TICKET" | cut -d '-' -f 1)
  local RESPONSE
  RESPONSE=$(createJiraSubtask "$SUBTASK_TITLE" "$SUBTASK_DESCRIPTION" "$PARENT_TICKET" "$PROJECT_KEY")

  if echo "$RESPONSE" | grep -q '"key":'; then
    local SUBTASK_KEY
    SUBTASK_KEY=$(echo "$RESPONSE" | jq -r '.key')
    log_success "Subtask created successfully: $SUBTASK_KEY"

    local BRANCH="feature/$SUBTASK_KEY"
    local SUBTASK_TICKET_URL="$JIRA_URL/browse/$SUBTASK_KEY"

    log "Transitioning subtask to 'In Progress'..."
    transitionJiraTicket "$SUBTASK_KEY"
    if [ $? -ne 0 ]; then
      log_error "Failed to transition subtask to 'In Progress'."
      return 1
    fi

    log "Assigning subtask to current user..."
    autoassignJiraTicket "$SUBTASK_KEY"
    if [ $? -ne 0 ]; then
      log_error "Failed to assign subtask to current user."
      return 1
    fi

    log "Creating feature branch $BRANCH..."
    git checkout -b "$BRANCH"
    if [ $? -ne 0 ]; then
      log_error "Failed to create feature branch."
      return 1
    fi

    log "Proceeding to commit and create PRs for the subtask..."

    git commit -m "$COMMIT_MESSAGE"
    if [ $? -ne 0 ]; then
      log_error "Failed to commit changes."
      return 1
    fi

    log "Pushing feature branch to remote..."
    git push -u origin "$BRANCH"
    if [ $? -ne 0 ]; then
      log_error "Failed to push feature branch to remote."
      return 1
    fi

    local COMMIT_TITLE
    COMMIT_TITLE=$(git log -1 --pretty=format:%s | sed 's/^:[^ ]* //')
    local COMMIT_BODY
    COMMIT_BODY=$(git log -1 --pretty=format:%b)

    local PR_BODY_DEVELOP
    PR_BODY_DEVELOP="[Link to Jira ticket]($SUBTASK_TICKET_URL)\n\n$COMMIT_BODY"

    log "Checking existing pull requests..."
    local EXISTING_PR_DEVELOP
    EXISTING_PR_DEVELOP=$(checkExistingPullRequest "develop" "$BRANCH")
    local EXISTING_PR_TEST
    EXISTING_PR_TEST=$(checkExistingPullRequest "deploy/test" "$BRANCH")

    local MESSAGE_TYPE="created"
    local PR_URL_DEVELOP
    local PR_URL_TEST

    if [ "$(echo "$EXISTING_PR_DEVELOP" | jq '. | length')" -gt 0 ]; then
      log "Existing pull request for develop found. Skipping creation."
      PR_URL_DEVELOP=$(echo "$EXISTING_PR_DEVELOP" | jq -r '.[0].html_url')
      MESSAGE_TYPE="updated"
    else
      log "Creating pull request for develop..."
      PR_URL_DEVELOP=$(createPullRequest "develop" ":test_tube: $COMMIT_TITLE" "$PR_BODY_DEVELOP" "$BRANCH")
      if [ -z "$PR_URL_DEVELOP" ]; then return 1; fi
      log "Pull request for develop created successfully: :test_tube: $COMMIT_TITLE."
      fi

    if [ "$(echo "$EXISTING_PR_TEST" | jq '. | length')" -eq 0 ]; then
      log "No existing pull request for deploy/test found."
      log "Deleting remote deploy/test branch..."
      git push origin --delete deploy/test

      log "Recreating remote deploy/test branch from develop..."
      git checkout develop
      git push origin develop:refs/heads/deploy/test

      log "Creating pull request for deploy/test..."
      local PR_BODY_TEST
      PR_BODY_TEST="[Link to Jira ticket]($SUBTASK_TICKET_URL)\n\n$COMMIT_BODY"
      PR_URL_TEST=$(createPullRequest "deploy/test" ":construction: $COMMIT_TITLE" "$PR_BODY_TEST" "$BRANCH")
      if [ -z "$PR_URL_TEST" ]; then return 1; fi
      log "Pull request for deploy/test created successfully: :construction: $COMMIT_TITLE."
    else
      log "Existing pull request for deploy/test found. Skipping creation."
      PR_URL_TEST=$(echo "$EXISTING_PR_TEST" | jq -r '.[0].html_url')
      MESSAGE_TYPE="updated"
    fi

    log "Sending PR details to Google Chat..."
    postToGoogleChat "$MESSAGE_TYPE" "$PR_URL_TEST" "$PR_URL_DEVELOP" "$COMMIT_TITLE" "$COMMIT_BODY" "$SUBTASK_TICKET_URL" "$SUBTASK_KEY"

    log_success "Commit and PRs created/updated successfully for $SUBTASK_KEY."

    # Mark ticket as In Progress and assign it to the user
    transitionJiraTicket "$SUBTASK_KEY"
    autoassignJiraTicket "$SUBTASK_KEY"

    log "Adding comment to Jira ticket..."
    addJiraComment "$SUBTASK_KEY" "$COMMIT_TITLE" "$COMMIT_BODY" "$PR_URL_DEVELOP" "$PR_URL_TEST"

    git checkout develop
  else
    log_error "Failed to create subtask in Jira."
    return 1
  fi
}

alias aipush="createAndPushTask"