#!/bin/bash

alias smartpush="createCommitAndPRs"
#alias deploytest="pushToDeployTest"
#alias deploydevelop="pushToDevelop"

# Prompts
DIFF_TO_COMMIT_MSG_PROMPT="Given the following diff, generate a conventional commit message (with type, scope, description, body).
The title should follow the format '<emoji> <type>(%s): <description>' or ':rotating_light: <type>(%s)!: <description>' for breaking changes.
Write it in simple English and in a markdown formatted text block without using triple backticks, except for the first and last.
Use one bullet level, and do not add another sentence after the bullets.
|
Use the appropriate emoji based on the commit type:
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
(the breaking changes emoji gains priority over the others, and adds a ! symbol before de colon)

Examples:

"

COMMIT_MESSAGE_EXAMPLE=":sparkles: feat(ATM-120): complete WorkstreamStatus component and add new status icons

- Finalized the implementation of the WorkstreamStatus component
- Added new SVG icons for various statuses
- Removed an unused import from the Snackbar component"


GENERATE_TESTS_PROMPT="Given the following code, generate a minimal set of Vite tests with Vitest and Sinon (not Jest) that covers 100% coverage (in simple English) with “it”.
Please provide the complete code. I already have vitest and sinon installed. I just want the complete spec code.
Feel free to ask me for code, examples, explanations, interfaces, whatever you need to accomplish the task satisfactorily.
Also, please add the necessary data-testid for the QA team to automate, so give me the main code modifications to add them.
The data-testid must be unique and must not be added to React components.

Do not add comments.
Avoid ESLint errors like ESLint: Unexpected any. Specify a different type. (@typescript-eslint/no-explicit-any)
Consider readonly and/or private methods and properties.
Make sure to import the following if using things like toBeInTheDocument: import '@testing-library/jest-dom'.
Pay attention to TS2339, TS2345 errors.
Do not use expect with toHaveTextContent or with i18n.
Also, do not use “vi.mock('react-i18next',...)”.
Remember not to use Jest.
Do not use \"as vi.Mock\" or \"as jest.Mock\".
If you don’t know, resolve it with sinon.
Do not use \"act\" as it is deprecated.
If you need information about an interface or the definition of an object, ask.
Do not add mock for i18next-react because I already have it defined in test-setup.
If applicable, watch out for the following errors:
- No QueryClient set, use QueryClientProvider to set one
- Cannot destructure property 'basename' of 'React__namespace.useContext(...)' as it is null

Additionally, ensure that all arrow functions use '=> void 0' instead of '=> {}'.

----

"

FIX_TESTS_PROMPT="Given the following code and its current test spec, improve or correct the test coverage to achieve 100% coverage using Vite tests with Vitest and Sinon (not Jest).
Please provide the complete corrected spec code. Do not add comments.
Avoid ESLint errors like ESLint: Unexpected any. Specify a different type. (@typescript-eslint/no-explicit-any)
Consider readonly and/or private methods and properties.
Make sure to import the following if using things like toBeInTheDocument: import '@testing-library/jest-dom'.
Pay attention to TS2339, TS2345 errors.
Do not use expect with toHaveTextContent or with i18n.
Also, do not use “vi.mock('react-i18next',...)”.
Remember not to use Jest.
Do not use \"as vi.Mock\" or \"as jest.Mock\". If you don’t know, resolve it with sinon.
Do not use \"act\" as it is deprecated. If you need information about an interface or the definition of an object, ask.
Do not add mock for i18next-react because I already have it defined in test-setup.
If applicable, watch out for the following errors:
- No QueryClient set, use QueryClientProvider to set one
- Cannot destructure property 'basename' of 'React__namespace.useContext(...)' as it is null.
Additionally, ensure that all arrow functions use '=> void 0' instead of '=> {}'.

----

"

SUBTASK_PROMPT="Create the task title and a brief description of the task that outputs the given diff,
as if it hasn't been started yet. The task title should be in sentence case.
Do not mention the diff explicitly. The description should be a single paragraph.
Do not use simple quotes (single or double) to prevent escaping errors."

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
  RESPONSE=$(curl "$@")  # Execute curl with all provided arguments
  clean_json_response "$RESPONSE"  # Clean the JSON response and return it directly
}

function log {
  echo -e "\033[1;34m$1\033[0m"
}

function log_warning {
  echo -e "\033[1;33m$1\033[0m"
}

function log_error {
  echo -e "\033[1;31m$1\033[0m"
}

function log_success {
  echo -e "\033[1;32m$1\033[0m"
}

function log_input {
  echo -e "\033[1;97m$1\033[0m"
}

function get_project_prefix {
  local PROJECT_KEY
  PROJECT_KEY=$(git config --get jira.project)
  echo "$PROJECT_KEY-"
}

function ensure_prefix {
  local TICKET="$1"
  local PROJECT_PREFIX
  PROJECT_PREFIX=$(get_project_prefix)
  if [[ ! "$TICKET" =~ ^$PROJECT_PREFIX ]]; then
    TICKET="$PROJECT_PREFIX$TICKET"
  fi
  echo "$TICKET"
}

function run_checks {
  skip_tests=false

  while getopts "s" opt; do
    case $opt in
      s)
        # shellcheck disable=SC2034
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
#  &&
#  if [ "$skip_tests" = false ]; then
#    nx run avantor-front-react:test --silent
#  fi
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
  echo -e "$PROMPT" | clip

  log "The commit message prompt has been copied to the clipboard. You can ask an AI to generate the commit message from it."
}

function copyComponentsAndStylesToClipboard {
  if [ -z "$1" ]; then
    log_error "Please provide a directory path."
    return 1
  fi

  local DIR_PATH="$1"
  if [ ! -d "$DIR_PATH" ]; then
    log_error "Directory ${DIR_PATH} does not exist."
    return 1
  fi

  local OUTPUT=""

  log "Finding .tsx, .ts and .scss files in ${DIR_PATH}..."
  while IFS= read -r -d '' FILE; do
    local SCSS_FILE=""
    local FILE_CONTENT=""
    local FILE_TYPE=""

    if [[ "$FILE" == *.tsx ]]; then
      FILE_TYPE="TSX"
      SCSS_FILE="${FILE%.tsx}.scss"
    elif [[ "$FILE" == *.ts ]]; then
      FILE_TYPE="TS"
      SCSS_FILE="${FILE%.ts}.scss"
    fi

    if [ ! -f "$FILE" ]; then
      log_warning "${FILE_TYPE} file ${FILE} not found."
      continue
    fi

    log "Reading ${FILE} contents..."
    FILE_CONTENT=$(< "$FILE")

#    local SCSS_CONTENT
#    if [ ! -f "$SCSS_FILE" ]; then
#      log_warning "SCSS file ${SCSS_FILE} not found for ${FILE_TYPE} file."
#      SCSS_CONTENT="/* No associated SCSS file found for ${FILE_TYPE} file. */"
#    else
#      log "Reading ${SCSS_FILE} contents..."
#      SCSS_CONTENT=$(< "$SCSS_FILE")
#    fi

    OUTPUT+="-----\n\n// ${FILE}\n\n${FILE_CONTENT}\n\n// ${SCSS_FILE}\n\n${SCSS_CONTENT}\n\n-----\n\n"
  done < <(find "$DIR_PATH" -type f \( -name "*.tsx" -o -name "*.ts" \) -print0)

  if [ -z "$OUTPUT" ]; then
    log_error "No .tsx or .ts files found in the directory."
    return 1
  fi

  log "Copying component and style contents to clipboard..."
  echo -e "$OUTPUT" | clip

  log "The components and styles contents have been copied to the clipboard."
}

function copyComponentAndSpecToClipboard {
  if [ -z "$1" ]; then
    log_error "Please provide a file name."
    return 1
  fi

  local FILE_NAME="$1"
  log "Finding main file..."
  local MAIN_FILE
  MAIN_FILE=$(find ./apps -type f \( -name "${FILE_NAME}.tsx" -o -name "${FILE_NAME}.ts" \) -print -quit)
  local SPEC_FILE
  SPEC_FILE=$(find ./apps -type f \( -name "${FILE_NAME}.spec.tsx" -o -name "${FILE_NAME}.spec.ts" \) -print -quit)

  if [ ! -f "$MAIN_FILE" ]; then
    log_error "Main file ${FILE_NAME}.tsx or ${FILE_NAME}.ts not found."
    return 1
  fi

  log "Reading main file contents..."
  local MAIN_CONTENT
  MAIN_CONTENT=$(< "$MAIN_FILE")

  if [ ! -f "$SPEC_FILE" ]; then
    log_warning "Spec file ${FILE_NAME}.spec.tsx or ${FILE_NAME}.spec.ts not found."
    SPEC_CONTENT=""
  else
    log "Reading spec file contents..."
    local SPEC_CONTENT
    SPEC_CONTENT=$(tr -d '[:space:]' < "$SPEC_FILE")
  fi

  log "Copying component and spec contents to clipboard..."
  echo -e "----\n\n$MAIN_FILE:\n\n${MAIN_CONTENT}\n\n----\n\n$SPEC_FILE:\n\n${SPEC_CONTENT}" | clip

  log "The component and spec contents have been copied to the clipboard."
}

function fixTests {
  if [ -z "$1" ]; then
    log_error "Please provide a file name."
    return 1
  fi

  local FILE_NAME="$1"
  local MAIN_FILE
  local SPEC_FILE
  local SELECTION
  local SPEC=""

  MAIN_FILE=$(find ./apps -type f \( -name "${FILE_NAME}.tsx" -o -name "${FILE_NAME}.ts" \) -print -quit)
  SPEC_FILE=$(find ./apps -type f \( -name "${FILE_NAME}.spec.tsx" -o -name "${FILE_NAME}.spec.ts" \) -print -quit)

  if [ ! -f "$MAIN_FILE" ]; then
    log_error "Main file ${FILE_NAME}.tsx or ${FILE_NAME}.ts not found."
    return 1
  fi

  SELECTION=$(< "$MAIN_FILE")

  if [ ! -f "$SPEC_FILE" ]; then
    if [ -f "${MAIN_FILE%.tsx}.tsx" ]; then
      SPEC_FILE="${MAIN_FILE%.tsx}.spec.tsx"
    elif [ -f "${MAIN_FILE%.ts}.ts" ]; then
      SPEC_FILE="${MAIN_FILE%.ts}.spec.ts"
    fi

    echo "" > "$SPEC_FILE"
    SPEC=""
  else
    local SPEC_CONTENT
    SPEC_CONTENT=$(tr -d '[:space:]' < "$SPEC_FILE")
    if [ -n "$SPEC_CONTENT" ]; then
      SPEC="\n\nTaking into consideration the existing spec\n\n$(cat "$SPEC_FILE")"
    fi
  fi

  local PROMPT
  PROMPT=$(echo -e "$FIX_TESTS_PROMPT\n\n----\n\n$MAIN_FILE:\n\n$SELECTION----\n\n$SPEC_FILE:\n\n$SPEC")

  log "Copying test correction prompt to clipboard..."
  echo -e "$PROMPT" | clip

  log "The test correction prompt has been copied to the clipboard. You can ask an AI to help improve the tests."
}

function generateTests {
  if [ -z "$1" ]; then
    log_error "Please provide a file name."
    return 1
  fi

  local FILE_NAME="$1"
  local MAIN_FILE
  local SPEC_FILE
  local SELECTION
  local SPEC=""

  MAIN_FILE=$(find ./apps -type f \( -name "${FILE_NAME}.tsx" -o -name "${FILE_NAME}.ts" \) -print -quit)

  if [ ! -f "$MAIN_FILE" ]; then
    log_error "Main file ${FILE_NAME}.tsx or ${FILE_NAME}.ts not found."
    return 1
  fi

  SELECTION=$(< "$MAIN_FILE")

  if [ ! -f "${MAIN_FILE%.tsx}.spec.tsx" ] && [ ! -f "${MAIN_FILE%.ts}.spec.ts" ]; then
    if [[ "$MAIN_FILE" == *.tsx ]]; then
      SPEC_FILE="${MAIN_FILE%.tsx}.spec.tsx"
    else
      SPEC_FILE="${MAIN_FILE%.ts}.spec.ts"
    fi
    touch "$SPEC_FILE"
    SPEC=""
  else
    SPEC_FILE=$(find ./apps -type f \( -name "${FILE_NAME}.spec.tsx" -o -name "${FILE_NAME}.spec.ts" \) -print -quit)
    local SPEC_CONTENT
    SPEC_CONTENT=$(tr -d '[:space:]' < "$SPEC_FILE")
    if [ -n "$SPEC_CONTENT" ]; then
      SPEC="\n\nTaking into consideration the existing spec\n\n$(cat "$SPEC_FILE")"
    fi
  fi

  local PROMPT
  PROMPT=$(echo -e "$GENERATE_TESTS_PROMPT\n\n----\n\n$MAIN_FILE:\n\n$SELECTION----\n\n$SPEC_FILE:\n\n$SPEC")

  log "Copying test generation prompt to clipboard..."
  echo -e "$PROMPT" | clip

  log "The test generation prompt has been copied to the clipboard. You can ask an AI to generate the tests from it."
}

function createPullRequest {
  local BASE="$1"
  local TITLE="$2"
  local BODY="$3"
  local HEAD="$4"
  local DRAFT_MODE="${5:-false}"

  local API_KEY
  API_KEY=$(git config --get github.token)
  local REPO
  REPO=$(git config --get remote.origin.url | sed -E 's/(git@|https:\/\/)([^\/:]+)[\/:]([^\/]+\/[^\/]+)\.git/\3/')
  local USER
  USER=$(safe_curl -s -H "Authorization: token $(git config --get github.token)" https://api.github.com/user | jq -r .login)
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

  if [ -z "$PR_URL" ]; then
    log_error "Failed to create pull request: $(echo "$RESPONSE" | jq -r '.message')"
    return 1
  fi

  # Add assignee after creating the PR
  local ASSIGNEE_DATA
  ASSIGNEE_DATA=$(jq -n --arg assignee "$USER" '{
    assignees: [$assignee]
  }')

  local ASSIGNEE_RESPONSE
  ASSIGNEE_RESPONSE=$(safe_curl -s -H "Authorization: token $API_KEY" -d "$ASSIGNEE_DATA" "https://api.github.com/repos/$ORG/$REPO_NAME/issues/$PR_NUMBER/assignees")

  if ! echo "$ASSIGNEE_RESPONSE" | grep -q '"login":'; then
    log_error "Failed to add assignee: $(echo "$ASSIGNEE_RESPONSE" | jq -r '.message')"
    return 1
  fi

#  # Get the default reviewer from git config
#  local DEFAULT_REVIEWER
#  DEFAULT_REVIEWER=$(git config --get github.default.reviewer)
#
#  local REVIEWER_DATA
#  REVIEWER_DATA=$(jq -n --arg reviewer "$DEFAULT_REVIEWER" '{
#    reviewers: [$reviewer]
#  }')
#
#  local REVIEWER_RESPONSE
#  REVIEWER_RESPONSE=$(safe_curl -s -H "Authorization: token $API_KEY" -d "$REVIEWER_DATA" "https://api.github.com/repos/$ORG/$REPO_NAME/pulls/$PR_NUMBER/requested_reviewers")
#
#  if ! echo "$REVIEWER_RESPONSE" | grep -q '"login":'; then
#    log_error "Failed to add reviewer: $(echo "$REVIEWER_RESPONSE" | jq -r '.message')"
#    return 1
#  fi

  echo "$PR_URL"
}

function checkExistingPullRequest {
  local BASE="$1"
  local HEAD="$2"

  local API_KEY
  API_KEY=$(git config --get github.token)
  local REPO
  REPO=$(git config --get remote.origin.url | sed -E 's/(git@|https:\/\/)([^\/:]+)[\/:]([^\/]+\/[^\/]+)\.git/\3/')
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

function createCommitAndPRs {
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

  # Stash any uncommitted changes with a unique name
  log "Stashing changes..."
  git stash push -m "Stash for $TICKET" || {
    log_error "Failed to stash changes."
    return 1
  }

  # Get the stash reference for later use (remove the trailing colon)
  local STASH_REF
  STASH_REF=$(git stash list | grep "Stash for $TICKET" | head -n 1 | awk '{print $1}' | sed 's/:$//')

  if [ -z "$STASH_REF" ]; then
    log_error "Failed to retrieve the stash reference."
    return 1
  fi

  # Switch to the develop branch
  log "Switching to develop branch..."
  git checkout develop || {
    log_error "Failed to checkout develop branch."
    git stash pop "$STASH_REF"
    return 1
  }

  log "Pulling latest changes from develop..."
  git pull origin develop || {
    log_error "Failed to pull latest changes from develop."
    git checkout -
    git stash pop "$STASH_REF"
    return 1
  }

  # Create or switch to the feature branch
  log "Creating or switching to feature branch '$BRANCH'..."
  git checkout -B "$BRANCH" || {
    log_error "Failed to create or switch to branch '$BRANCH'."
    git checkout develop
    git stash pop "$STASH_REF"
    return 1
  }

  # Apply stashed changes to the feature branch
  log "Applying stashed changes to feature branch..."
  git stash apply "$STASH_REF" || {
    log_error "Failed to apply stashed changes to feature branch."
    git checkout develop
    return 1
  }

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

  # Check if the remote branch exists
  log "Checking if remote branch '$BRANCH' exists..."
  if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null; then
    log "Remote branch exists. Pulling latest changes..."
    git pull origin "$BRANCH" || {
      log_error "Failed to pull latest changes from remote branch '$BRANCH'."
      git checkout develop
      return 1
    }
  else
    log "Remote branch does not exist. It will be created."
  fi

  # Push the feature branch to remote
  if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null; then
    log "Pushing feature branch '$BRANCH' to remote with --force-with-lease..."
    git push -u origin "$BRANCH" --force-with-lease || {
      log_error "Failed to push feature branch '$BRANCH' to remote."
      git checkout develop
      return 1
    }
  else
    log "Pushing new feature branch '$BRANCH' to remote..."
    git push -u origin "$BRANCH" || {
      log_error "Failed to push new feature branch '$BRANCH' to remote."
      git checkout develop
      return 1
    }
  fi

  # Get the latest commit title and body
  local COMMIT_TITLE
  COMMIT_TITLE=$(git log -1 --pretty=format:%s | sed 's/^:[^ ]* //')

  local COMMIT_BODY
  COMMIT_BODY=$(git log -1 --pretty=format:%b)

  # Replace typographic quotes with straight quotes in the commit title and body
  COMMIT_TITLE=$(echo "$COMMIT_TITLE" | sed "s/[’‘]/'/g; s/[“”]/\"/g")
  COMMIT_BODY=$(echo "$COMMIT_BODY" | sed "s/[’‘]/'/g; s/[“”]/\"/g")

  # Delete the local deploy/test branch if it exists
  log "Deleting local deploy/test branch if it exists..."
  git branch -D deploy/test >/dev/null 2>&1 || log_warning "Local deploy/test branch does not exist."

  # Checkout the deploy/test branch from remote
  log "Checking out deploy/test branch..."
  if ! git checkout deploy/test; then
    log_error "deploy/test branch does not exist remotely."
    git checkout develop
    return 1
  fi

  log "Fetching latest changes for deploy/test..."
  git fetch origin deploy/test || {
    log_error "Failed to fetch latest changes for deploy/test."
    git checkout develop
    return 1
  }

  # Apply stashed changes to deploy/test
  log "Applying stashed changes to deploy/test..."
  git stash apply "$STASH_REF" || {
    log_error "Failed to apply stashed changes to deploy/test."
      git checkout develop
      return 1
  }

  # Drop the stash after applying to deploy/test
  git stash drop "$STASH_REF" || {
    log_warning "Failed to drop stash '$STASH_REF'. Please drop it manually."
  }

  # Run checks again on deploy/test
  log "Running type check, linting, formatting, and tests on deploy/test..."
  if ! run_checks; then
    log_error "Type check, linting, formatting, or tests failed on deploy/test. Aborting."
    git checkout develop
    return 1
  fi

  # Stage all changes on deploy/test
  log "Staging all changes on deploy/test..."
  git add . || {
    log_error "Failed to stage changes on deploy/test."
    git checkout develop
    return 1
  }

  # Commit changes on deploy/test
  log "Committing changes on deploy/test..."
  git commit -m "Apply changes from $BRANCH" || {
    log_error "Failed to commit changes on deploy/test."
    git checkout develop
    return 1
  }

  # Push the updated deploy/test branch to remote
  log "Pushing updated deploy/test branch to remote..."
  git push origin deploy/test || {
    log_error "Failed to push updated deploy/test branch to remote."
    git checkout develop
    return 1
  }

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
  postToGoogleChat "created" "$PR_URL_DEVELOP" "$COMMIT_TITLE" "$COMMIT_BODY" "$TICKET_URL" "$TICKET" || {  # Updated line
    log_warning "Failed to send Pull Request details to Google Chat."
  }

  log_success "Commit and PRs created/updated successfully for $TICKET."

  # Update Jira ticket: transition and assign
  log "Updating Jira ticket '$TICKET'..."
  transitionJiraTicket "$TICKET" || log_warning "Failed to transition Jira ticket '$TICKET'."
  autoassignJiraTicket "$TICKET" || log_warning "Failed to assign Jira ticket '$TICKET'."

  # Add a comment to the Jira ticket
  log "Adding comment to Jira ticket..."
  addJiraComment "$TICKET" "$COMMIT_TITLE" "$COMMIT_BODY" "$PR_URL_DEVELOP" || log_warning "Failed to add comment to Jira ticket."

  # Switch back to the develop branch
  log "Switching back to develop branch..."
  git checkout develop || {
    log_error "Failed to switch back to develop branch."
    return 1
  }

  log_success "Operation completed successfully for ticket '$TICKET'."
}

# General function to sync a release branch with any target branch
function syncReleaseWith {
  local RELEASE_BRANCH="$1"
  local TARGET_BRANCH="$2"
  local SYNC_BRANCH="sync-${RELEASE_BRANCH}-with-${TARGET_BRANCH}"

  # Check if the release branch is provided
  if [ -z "$RELEASE_BRANCH" ]; then
    log_error "Please provide a release branch name as the first parameter."
    echo "Usage: syncReleaseWith <release-branch> <target-branch>"
    return 1
  fi

  # Check if the target branch is provided
  if [ -z "$TARGET_BRANCH" ]; then
    log_error "Please provide a target branch name as the second parameter."
    echo "Usage: syncReleaseWith <release-branch> <target-branch>"
    return 1
  fi

  # Validate if the release branch exists
  if ! git show-ref --verify --quiet "refs/heads/$RELEASE_BRANCH"; then
    log_error "The release branch '$RELEASE_BRANCH' does not exist."
    return 1
  fi

  # Validate if the target branch exists
  if ! git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    log_error "The target branch '$TARGET_BRANCH' does not exist."
    return 1
  fi

  # 1. Switch to the release branch and update it
  log "Switching to branch '$RELEASE_BRANCH' and updating it..."
  git checkout "$RELEASE_BRANCH" || { log_error "Failed to switch to branch '$RELEASE_BRANCH'."; return 1; }
  git pull origin "$RELEASE_BRANCH" || { log_error "Failed to update branch '$RELEASE_BRANCH'."; return 1; }

  # 2. Create or switch to the synchronization branch
  if git show-ref --quiet refs/heads/"$SYNC_BRANCH"; then
    log "Synchronization branch '$SYNC_BRANCH' already exists locally. Switching to it..."
    git checkout "$SYNC_BRANCH" || { log_error "Failed to switch to branch '$SYNC_BRANCH'."; return 1; }
    # Check if the remote sync branch exists
    if git ls-remote --exit-code --heads origin "$SYNC_BRANCH" > /dev/null 2>&1; then
      git pull origin "$SYNC_BRANCH" || { log_error "Failed to update branch '$SYNC_BRANCH'."; return 1; }
    else
      log "Remote synchronization branch '$SYNC_BRANCH' does not exist. It will be pushed later."
    fi
  else
    log "Creating synchronization branch '$SYNC_BRANCH' from '$RELEASE_BRANCH'..."
    git checkout -b "$SYNC_BRANCH" || { log_error "Failed to create branch '$SYNC_BRANCH'."; return 1; }
  fi

  # 3. Merge the target branch into the synchronization branch
  log "Merging '$TARGET_BRANCH' into '$SYNC_BRANCH'..."
  if git merge "$TARGET_BRANCH" --no-ff -m "Merge $TARGET_BRANCH into $RELEASE_BRANCH for synchronization"; then
    log_success "Merge completed successfully without conflicts."
  else
    log_error "Conflicts encountered during merge. Resolving 'pom.xml' to keep '$RELEASE_BRANCH' version."

    # Resolve conflicts by keeping 'pom.xml' from release branch
    git checkout "$RELEASE_BRANCH" -- pom.xml
    git add pom.xml

    # Continue the merge by committing the resolution
    git commit --no-edit || { log_error "Failed to commit the resolved 'pom.xml'."; return 1; }

    log_success "Conflicts in 'pom.xml' resolved by keeping '$RELEASE_BRANCH' version."
  fi

  # 4. Verify the commit history
  log "Verifying commit history in '$SYNC_BRANCH'..."
  git log --oneline

  # 5. Push the synchronization branch to remote
  log "Pushing branch '$SYNC_BRANCH' to remote..."
  git push origin "$SYNC_BRANCH" || { log_error "Failed to push branch '$SYNC_BRANCH'."; return 1; }

  # 6. Create a Pull Request
  local PR_TITLE="Sync $TARGET_BRANCH into $RELEASE_BRANCH"

  # Get commit messages for the PR description
  local COMMIT_MESSAGES
  COMMIT_MESSAGES=$(git log "$RELEASE_BRANCH".."$SYNC_BRANCH" --pretty=format:"- %s")

  local PR_BODY="This PR synchronizes the \`$TARGET_BRANCH\` branch with \`$RELEASE_BRANCH\`.\n\n**Included Changes:**\n$COMMIT_MESSAGES"

  log "Creating Pull Request with title: \"$PR_TITLE\" and description:\n$PR_BODY"

  local PR_URL
  PR_URL=$(createPullRequest "$RELEASE_BRANCH" "$PR_TITLE" "$PR_BODY" "$SYNC_BRANCH")

  if [ -z "$PR_URL" ]; then
    log_error "Failed to create the Pull Request."
    return 1
  else
    log_success "Pull Request created successfully: $PR_URL"
  fi

  # 7. Switch back to the release branch
  git checkout "$RELEASE_BRANCH" || { log_error "Failed to switch back to branch '$RELEASE_BRANCH'."; return 1; }

  log_success "Synchronization of '$TARGET_BRANCH' into '$RELEASE_BRANCH' completed successfully."
}

# Alias function to sync release branch with 'develop'
function syncReleaseWithDevelop {
  local RELEASE_BRANCH="$1"
  syncReleaseWith "$RELEASE_BRANCH" "develop"
}

# Function to get clipboard content based on the operating system
get_clipboard_content() {
  if command -v pbpaste &>/dev/null; then
    pbpaste  # macOS
  elif command -v xclip &>/dev/null; then
    xclip -selection clipboard -o  # Linux with xclip
  elif command -v powershell.exe &>/dev/null; then
    powershell.exe Get-Clipboard  # Windows (Git Bash)
  else
    echo "Could not access clipboard." >&2
    return 1
  fi
}

# Function to copy content to clipboard based on the operating system
copy_to_clipboard() {
  if command -v pbcopy &>/dev/null; then
    pbcopy  # macOS
  elif command -v xclip &>/dev/null; then
    xclip -selection clipboard  # Linux with xclip
  elif command -v powershell.exe &>/dev/null; then
    clip.exe  # Windows (Git Bash)
  else
    echo "Could not copy to clipboard." >&2
    return 1
  fi
}

# Function to simplify the curl command by keeping only essential headers
simplify_clipboard_curl() {
  # Get clipboard content
  clipboard_content=$(get_clipboard_content)

  # Verify if clipboard content is a curl command
  if [[ "$clipboard_content" =~ ^curl ]]; then
    echo "Simplifying the curl command from clipboard..."

    # Define essential headers to keep
    essential_headers=("authorization" "x-host" "x-platform")

    # Filter essential headers and rebuild the curl command
    simplified_curl=$(echo "$clipboard_content" | grep -E "$(IFS=\| ; echo "${essential_headers[*]}")|^curl")

    # Remove trailing backslash from the last line, if present
    simplified_curl=$(echo "$simplified_curl" | sed '$s/\\$//')

    # Copy the simplified command back to the clipboard
    echo "$simplified_curl" | copy_to_clipboard
    echo "Simplified curl command has been copied to the clipboard."
  else
    echo "Clipboard content is not a curl command." >&2
  fi
}

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

  if [ -z "$TITLE" ]; then
    log_error "Failed to get Jira ticket title."
    return 1
  fi

  echo "$TITLE"
}

function createJiraSubtask {
  local SUMMARY="$1"
  local DESCRIPTION="$2"
  local PARENT_TICKET="$3"
  local PROJECT_KEY="$4"
  local API_KEY
  API_KEY=$(git config --get jira.token)
  local JIRA_URL
  JIRA_URL=$(git config --get jira.url)
  local PARENT_ISSUE_ID
  PARENT_ISSUE_ID=$(safe_curl -s -u "$(git config --get jira.email):$API_KEY" -H "Content-Type: application/json" -X GET "$JIRA_URL/rest/api/2/issue/$PARENT_TICKET")

  PARENT_ISSUE_ID=$(clean_json_response "$PARENT_ISSUE_ID")

  local PARENT_ID
  PARENT_ID=$(echo "$PARENT_ISSUE_ID" | jq -r '.id')
  if [ -z "$PARENT_ID" ]; then
    log_error "Failed to get parent issue ID."
    return 1
  fi

  local SUBTASK_DATA
  SUBTASK_DATA=$(jq -n --arg summary "$SUMMARY" --arg description "$DESCRIPTION" --arg parentId "$PARENT_ID" --arg projectId "10046" '{
    fields: {
      project: {
        id: $projectId
      },
      issuetype: {
        id: "10131" # ID for "Sub-task"
      },
      parent: {
        id: $parentId
      },
      summary: $summary,
      description: $description
    }
  }')

  local RESPONSE
  RESPONSE=$(safe_curl -s -u "$(git config --get jira.email):$API_KEY" -H "Content-Type: application/json" -d "$SUBTASK_DATA" "$JIRA_URL/rest/api/2/issue")

  RESPONSE=$(clean_json_response "$RESPONSE")

  echo "$RESPONSE"
}

function transitionJiraTicket {
  local TICKET="$1"
  local TRANSITION_ID="${2:-21}"  # Use the provided transition ID or default to 21 (In Progress)
  local API_KEY
  API_KEY=$(git config --get jira.token)
  local JIRA_URL
  JIRA_URL=$(git config --get jira.url)
  local USER
  USER=$(git config --get jira.email)

  # Determine the name of the status based on the transition ID
  local STATUS_NAME=""
  case "$TRANSITION_ID" in
    11)
      STATUS_NAME="To Do"
      ;;
    21)
      STATUS_NAME="In Progress"
      ;;
    31)
      STATUS_NAME="Done"
      ;;
    *)
      STATUS_NAME="Unknown Status"
      ;;
  esac

  local TRANSITION_DATA
  TRANSITION_DATA=$(jq -n --arg id "$TRANSITION_ID" '{
    transition: {
      id: $id
    }
  }')

  local HTTP_STATUS
  HTTP_STATUS=$(safe_curl -s -o /dev/null -w '%{http_code}' -u "$USER:$API_KEY" -H "Content-Type: application/json" -d "$TRANSITION_DATA" "$JIRA_URL/rest/api/2/issue/$TICKET/transitions")

  if [ "$HTTP_STATUS" -eq 204 ]; then
    log_success "Ticket $TICKET moved to $STATUS_NAME state."
  elif [ "$HTTP_STATUS" -eq 409 ]; then
    log_warning "Ticket $TICKET is already in the $STATUS_NAME state."
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
  local PR_TITLE="$2"
  local PR_BODY="$3"
  local PR_URL_DEVELOP="$4"
  local API_KEY
  API_KEY=$(git config --get jira.token)
  local JIRA_URL
  JIRA_URL=$(git config --get jira.url)
  local USER
  USER=$(git config --get jira.email)

  # Replace \n in PR_BODY with real new lines
  local FORMATTED_PR_BODY
  FORMATTED_PR_BODY=$(echo "$PR_BODY" | sed 's/\\n/\
/g')

  # Construct the comment body without deploy/test PR
  local COMMENT_BODY
  COMMENT_BODY=$(jq -n --arg pr_title "$PR_TITLE" \
                           --arg pr_body "$FORMATTED_PR_BODY" \
                           --arg pr_url_develop "$PR_URL_DEVELOP" \
                           '{
    type: "doc",
    version: 1,
    content: [
      {
        type: "heading",
        attrs: { level: 3 },
        content: [
          {
            type: "text",
            text: "Pull Request created: "
          },
          {
            type: "text",
            text: $pr_title
          }
        ]
      },
      {
        type: "paragraph",
        content: [
          {
            type: "text",
            text: "Develop Pull Request",
            marks: [
              {
                type: "link",
                attrs: {
                  href: $pr_url_develop
                }
              }
            ]
          }
        ]
      },
      {
        type: "paragraph",
        content: [
          {
            type: "text",
            text: $pr_body
          }
        ]
      }
    ]
  }')

  local COMMENT_DATA
  COMMENT_DATA=$(jq -n --argjson body "$COMMENT_BODY" '{body: $body}')

  local HTTP_STATUS
  HTTP_STATUS=$(safe_curl -s -o /dev/null -w '%{http_code}' -u "$USER:$API_KEY" -H "Content-Type: application/json" -d "$COMMENT_DATA" "$JIRA_URL/rest/api/3/issue/$TICKET/comment")

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

function createSubTaskFromDiff {
  if [ -z "$1" ]; then
    log_error "Please provide a parent ticket number."
    return 1
  fi

  log "Ensuring ticket prefix..."
  local PARENT_TICKET
  PARENT_TICKET=$(ensure_prefix "$1")

  log "Staging changes..."
  git add .

  log "Generating diff..."
  local DIFF
  DIFF=$(git diff --staged)

  if [ -z "$DIFF" ]; then
    log_warning "No changes detected. Please make some changes before creating a subtask."
    return 1
  fi

  local PROMPT
  PROMPT=$(echo -e "$SUBTASK_PROMPT\n\n---\n\n$DIFF")

  log "Copying subtask creation prompt to clipboard..."
  echo -e "$PROMPT" | clip

  log "The subtask creation prompt has been copied to the clipboard. You can ask an AI to generate the title and description from it."

  log_input "Please enter the title of the subtask:"
  read -r SUBTASK_TITLE

  log_input "Please enter the description of the subtask:"
  read -r SUBTASK_DESCRIPTION

  local PROJECT_KEY
  PROJECT_KEY=$(echo "$PARENT_TICKET" | cut -d '-' -f 1)

  log "Creating subtask in Jira..."
  local RESPONSE
  RESPONSE=$(createJiraSubtask "$SUBTASK_TITLE" "$SUBTASK_DESCRIPTION" "$PARENT_TICKET" "$PROJECT_KEY")

  RESPONSE=$(clean_json_response "$RESPONSE")

  if echo "$RESPONSE" | grep -q '"key":'; then
    local SUBTASK_KEY
    SUBTASK_KEY=$(echo "$RESPONSE" | jq -r '.key')
    log_success "Subtask created successfully: $SUBTASK_KEY"

    log "Transitioning subtask to 'In Progress'..."
    transitionJiraTicket "$SUBTASK_KEY"

    log "Assigning subtask to current user..."
    autoassignJiraTicket "$SUBTASK_KEY"
  else
    log_error "Failed to create subtask."
    return 1
  fi
}

function postToGoogleChat {
  local MESSAGE_TYPE="$1"
  local URL_DEVELOP="$2"
  local TITLE="$3"
  local DESCRIPTION="$4"
  local TICKET_URL="$5"
  local TICKET="$6"
  local WEBHOOK_URL
  WEBHOOK_URL="$(git config --get chat.webhook.url)"

  if [ -z "$WEBHOOK_URL" ]; then
    log_error "Google Chat webhook URL is not set."
    return 1
  fi

  local TICKET_TITLE
  TICKET_TITLE=$(get_jira_ticket_title "$TICKET")

  local JIRA_LINK="<a href=\"$TICKET_URL\" target=\"_blank\">Jira Ticket</a>"
  local PR_LINK_DEVELOP="<a href=\"$URL_DEVELOP\" target=\"_blank\">Develop Pull Request</a>"
  local PR_TITLE_HTML="<b>$TITLE</b>"
  local PR_DESCRIPTION_HTML="$DESCRIPTION"
  local DRAFT_STATUS="<b>Status:</b> Draft - Awaiting Proofs from Author"
  local NEXT_STEPS="<b>Next Steps:</b><br>1. <i>Author:</i> Attach proofs.<br>2. <i>Reviewers:</i> Keep reviewing the PR."

  # Construct the JSON payload without deploy/test PR
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

function reset_feature_branch {
  local TICKET
  TICKET=$(ensure_prefix "$1")
  local BRANCH="feature/$TICKET"
  git checkout "$BRANCH"
  git reset HEAD~1 --soft
  git stash
  git checkout develop
  git branch -D "$BRANCH"
  git push origin --delete "$BRANCH"
  git stash pop
  smartpush "$1"
}

function syncBranch {
  local BRANCH
  BRANCH=$(git branch --show-current)

  if [ -z "$BRANCH" ]; then
    log_error "Failed to determine the current branch."
    return 1
  fi

  log "Stashing current changes..."
  git stash

  log "Pulling latest changes from $BRANCH..."
  git pull --prune origin "$BRANCH"

  log "Popping stashed changes..."
  git stash pop || true

  log_success "Branch $BRANCH synchronized successfully."
}

function postMergeSync {
  log "Resetting deploy/test branch to match develop..."

  # Stash any uncommitted changes
  git stash

  # Checkout develop branch and pull the latest changes
  git checkout develop
  git pull origin develop

  # Delete local deploy/test branch if it exists
  if git rev-parse --verify deploy/test >/dev/null 2>&1; then
    git branch -D deploy/test
  fi

  # Create a new deploy/test branch from develop
  git checkout -b deploy/test

  # Force push the updated deploy/test branch
  git push origin deploy/test --force

  # Return to the develop branch
  git checkout develop

  # Delete the deploy/test branch locally
  git branch -D deploy/test

  log_success "deploy/test branch has been reset to match develop and deleted locally."

  # Move the Jira ticket to "Done"
  local TICKET_NUMBER="$1"
  local TICKET
  TICKET=$(ensure_prefix "$TICKET_NUMBER")
  local DONE_TRANSITION_ID="31" # Replace this with the correct ID for "Done" in your Jira instance

  if [ -n "$TICKET" ]; then
    transitionJiraTicket "$TICKET" "$DONE_TRANSITION_ID"
  else
    log_warning "No Jira ticket number provided, skipping ticket transition."
  fi
}

# Function to get the list of pull requests
function get_pull_requests {
  local BASE_BRANCH=$1
  local API_KEY
  local REPO
  local ORG
  local REPO_NAME
  local API_URL

  API_KEY=$(git config --get github.token)
  REPO=$(git config --get remote.origin.url | sed -E 's/(git@|https:\/\/)([^\/:]+)[\/:]([^\/]+\/[^\/]+)\.git/\3/')
  ORG=$(echo "$REPO" | cut -d '/' -f 1)
  REPO_NAME=$(echo "$REPO" | cut -d '/' -f 2)
  API_URL="https://api.github.com/repos/$ORG/$REPO_NAME/pulls?base=$BASE_BRANCH&state=open&sort=created&direction=asc"

  safe_curl -s -H "Authorization: token $API_KEY" "$API_URL"
}

# Function to merge a pull request using squash
# TODO: Change this to rebase when Jona me de bola :(
function merge_pull_request {
  local PR_NUMBER=$1
  local TRIGGER=$2
  local API_KEY
  local REPO
  local ORG
  local REPO_NAME
  local API_URL
  local JSON_DATA

  API_KEY=$(git config --get github.token)
  REPO=$(git config --get remote.origin.url | sed -E 's/(git@|https:\/\/)([^\/:]+)[\/:]([^\/]+\/[^\/]+)\.git/\3/')
  ORG=$(echo "$REPO" | cut -d '/' -f 1)
  REPO_NAME=$(echo "$REPO" | cut -d '/' -f 2)
  API_URL="https://api.github.com/repos/$ORG/$REPO_NAME/pulls/$PR_NUMBER/merge"

  JSON_DATA=$(jq -n \
    --arg commit_title "Auto-merge PR #$PR_NUMBER triggered by $TRIGGER" \
    --arg merge_method "squash" \
    '{commit_title: $commit_title, merge_method: $merge_method}')

  safe_curl -s -X PUT -H "Authorization: token $API_KEY" \
       -H "Content-Type: application/json" \
       -d "$JSON_DATA" \
       "$API_URL" > /dev/null
}

# Function to check if a pull request is approved
function is_approved {
  local PR_NUMBER=$1
  local API_KEY
  local REPO
  local ORG
  local REPO_NAME
  local API_URL
  local REVIEWS
  local APPROVED

  API_KEY=$(git config --get github.token)
  REPO=$(git config --get remote.origin.url | sed -E 's/(git@|https:\/\/)([^\/:]+)[\/:]([^\/]+\/[^\/]+)\.git/\3/')
  ORG=$(echo "$REPO" | cut -d '/' -f 1)
  REPO_NAME=$(echo "$REPO" | cut -d '/' -f 2)
  API_URL="https://api.github.com/repos/$ORG/$REPO_NAME/pulls/$PR_NUMBER/reviews"
  REVIEWS=$(safe_curl -s -H "Authorization: token $API_KEY" "$API_URL")
  APPROVED=$(echo "$REVIEWS" | jq '[.[] | select(.state == "APPROVED")] | length')

  if [ "$APPROVED" -gt 0 ]; then
    return 0
  else
    return 1
  fi
}

# Function to approve a pull request
function approve_pull_request {
  local PR_NUMBER=$1
  local API_KEY
  local REPO
  local ORG
  local REPO_NAME
  local API_URL
  local JSON_DATA

  API_KEY=$(git config --get github.token)
  REPO=$(git config --get remote.origin.url | sed -E 's/(git@|https:\/\/)([^\/:]+)[\/:]([^\/]+\/[^\/]+)\.git/\3/')
  ORG=$(echo "$REPO" | cut -d '/' -f 1)
  REPO_NAME=$(echo "$REPO" | cut -d '/' -f 2)
  API_URL="https://api.github.com/repos/$ORG/$REPO_NAME/pulls/$PR_NUMBER/reviews"

  JSON_DATA=$(jq -n \
    --arg event "APPROVE" \
    '{event: $event}')

  safe_curl -s -X POST -H "Authorization: token $API_KEY" \
       -H "Content-Type: application/json" \
       -d "$JSON_DATA" \
       "$API_URL" > /dev/null

  if [ $? -eq 0 ]; then
    log_success "Successfully approved PR #$PR_NUMBER"
  else
    log_error "Failed to approve PR #$PR_NUMBER"
  fi
}

# Function to post a comment on a PR
function post_comment {
  local PR_NUMBER=$1
  local COMMENT=$2
  local API_KEY
  local REPO
  local ORG
  local REPO_NAME
  local API_URL

  API_KEY=$(git config --get github.token)
  REPO=$(git config --get remote.origin.url | sed -E 's/(git@|https:\/\/)([^\/:]+)[\/:]([^\/]+\/[^\/]+)\.git/\3/')
  ORG=$(echo "$REPO" | cut -d '/' -f 1)
  REPO_NAME=$(echo "$REPO" | cut -d '/' -f 2)
  API_URL="https://api.github.com/repos/$ORG/$REPO_NAME/issues/$PR_NUMBER/comments"

  safe_curl -s -X POST -H "Authorization: token $API_KEY" -H "Content-Type: application/json" \
       -d "{\"body\": \"$COMMENT\"}" "$API_URL" > /dev/null
}

function cascadeMerge {
  local DEVELOP_BRANCH="develop"
  local DEPLOY_TEST_BRANCH="deploy/test"
  local TRIGGER=${1:-"manual trigger"}

  local DEVELOP_PRS
  DEVELOP_PRS=$(get_pull_requests "$DEVELOP_BRANCH")
  local DEPLOY_TEST_PRS
  DEPLOY_TEST_PRS=$(get_pull_requests "$DEPLOY_TEST_BRANCH")

  # Merge approved PRs in develop branch
  for PR in $(echo "$DEVELOP_PRS" | jq -r '.[] | @base64'); do
    _jq() {
      echo "${PR}" | base64 --decode | jq -r "${1}"
    }

    local PR_NUMBER
    PR_NUMBER=$(_jq '.number')
    local PR_TITLE
    PR_TITLE=$(_jq '.title')
    local PR_HEAD
    PR_HEAD=$(_jq '.head.ref')

    local TICKET_NUMBER_FROM_BRANCH
    TICKET_NUMBER_FROM_BRANCH=$(echo "$PR_HEAD" | sed -n 's/^feature\/\([0-9]*\)/\1/p')

    local TICKET_NUMBER_FROM_TITLE
    TICKET_NUMBER_FROM_TITLE=$(echo "$PR_TITLE" | sed -n 's/.*(\([0-9]*\)).*/\1/p')

    local TICKET_NUMBER
    TICKET_NUMBER="${TICKET_NUMBER_FROM_BRANCH:-$TICKET_NUMBER_FROM_TITLE}"

    # Remove the first emoji from the title for comparison
    local PR_TITLE_NO_EMOJI
    PR_TITLE_NO_EMOJI=$(echo "$PR_TITLE" | sed 's/^:[^:]*: //')

    if is_approved "$PR_NUMBER"; then
      log "Merging approved PR #$PR_NUMBER: $PR_TITLE"
      merge_pull_request "$PR_NUMBER" "$TRIGGER"

      if [ $? -eq 0 ]; then
        log_success "Successfully merged PR #$PR_NUMBER: $PR_TITLE"
        post_comment "$PR_NUMBER" ":rocket: This PR was successfully merged via *cascadeMerge* triggered by $TRIGGER."

        # Send notification to Google Chat
        sendGoogleChatNotification "\u2705 *Develop* branch has been merged. Remember to _pull_ the latest changes!"

        # Check for corresponding deploy/test PR with the same title (ignoring the emoji)
        for DTPR in $(echo "$DEPLOY_TEST_PRS" | jq -r '.[] | @base64'); do
          _jq_dt() {
            echo "${DTPR}" | base64 --decode | jq -r "${1}"
          }

          local DTPR_NUMBER
          DTPR_NUMBER=$(_jq_dt '.number')
          local DTPR_TITLE
          DTPR_TITLE=$(_jq_dt '.title')

          # Remove the first emoji from the deploy/test title
          local DTPR_TITLE_NO_EMOJI
          DTPR_TITLE_NO_EMOJI=$(echo "$DTPR_TITLE" | sed 's/^:[^:]*: //')

          if [[ "$DTPR_TITLE_NO_EMOJI" == "$PR_TITLE_NO_EMOJI" ]]; then
            log "Merging corresponding deploy/test PR #$DTPR_NUMBER for feature branch $PR_HEAD"

            # Check if the deploy/test PR is approved before merging
            if is_approved "$DTPR_NUMBER"; then
              merge_pull_request "$DTPR_NUMBER" "$TRIGGER"

              if [ $? -eq 0 ]; then
                log_success "Successfully merged deploy/test PR #$DTPR_NUMBER for feature branch $PR_HEAD"
                post_comment "$DTPR_NUMBER" ":rocket: This PR was successfully merged via *cascadeMerge* triggered by $TRIGGER."
              else
                log_error "Failed to merge deploy/test PR #$DTPR_NUMBER for feature branch $PR_HEAD"
                post_comment "$DTPR_NUMBER" ":warning: Failed to merge via *cascadeMerge* triggered by $TRIGGER."
              fi
            else
              log "Skipping deploy/test PR #$DTPR_NUMBER: $DTPR_TITLE (not approved)"
            fi
          fi
        done

        # Run postMergeSync to update deploy/test branch
        postMergeSync "$TICKET_NUMBER"
      else
        log_error "Failed to merge PR #$PR_NUMBER: $PR_TITLE"
        post_comment "$PR_NUMBER" ":warning: Failed to merge via *cascadeMerge* triggered by $TRIGGER."
      fi
    else
      log "Skipping PR #$PR_NUMBER: $PR_TITLE (not approved)"
    fi
  done
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

function generateChangelog {
  local CHANGELOG_FILE="CHANGELOG.md"

  # Get the GitHub and Jira URLs from git config
  local REPO_URL
  REPO_URL=$(git config --get remote.origin.url | sed -E 's/git@github\.com:/https:\/\/github.com\//; s/\.git$//')

  local JIRA_URL
  JIRA_URL=$(git config --get jira.url)

  # Start the changelog generation
  log "Generating changelog..."

  # Create or overwrite the changelog file
  log "Creating changelog header..."
  echo "# Changelog" > $CHANGELOG_FILE
  echo "" >> $CHANGELOG_FILE

  # Extract commit messages in one go, filtering out unwanted commits
  log "Extracting and processing commit messages..."
  local COMMIT_LOG
  COMMIT_LOG=$(git log --pretty=format:"%ad %s %h" --date=short --abbrev-commit | grep -v -e "Auto-merge" -e "UPDATE THIS MESSAGE" -e "Merge branch" -e "Merge pull request")

  local CURRENT_DATE=""
  local CURRENT_TICKET=""
  local TEMP_CHANGELOG=""

  # Process the commit log
  while IFS= read -r line; do
    local DATE=$(echo "$line" | awk '{print $1}')
    local MESSAGE=$(echo "$line" | cut -d ' ' -f2-)
    local TICKET=$(echo "$MESSAGE" | grep -oE "(ATM-[0-9]+)")
    local COMMIT_HASH=$(echo "$MESSAGE" | awk '{print $NF}')
    local PR_NUMBER=""

    if [[ "$MESSAGE" =~ \#([0-9]+) ]]; then
      PR_NUMBER="${BASH_REMATCH[1]}"
    fi

    # If the date changes, add a new date section
    if [ "$CURRENT_DATE" != "$DATE" ]; then
      CURRENT_DATE="$DATE"
      TEMP_CHANGELOG+="\n## $CURRENT_DATE\n\n"
      CURRENT_TICKET=""
    fi

    # If the current ticket changes, add a new ticket section with its Jira title
    if [ "$CURRENT_TICKET" != "$TICKET" ]; then
      CURRENT_TICKET="$TICKET"
      local TICKET_URL="$JIRA_URL/browse/$TICKET"
      local TICKET_TITLE=$(get_jira_ticket_title "$TICKET")
      TEMP_CHANGELOG+="- [$CURRENT_TICKET]($TICKET_URL): **$TICKET_TITLE**\n"
    fi

    # Clean the commit title by removing unnecessary parts
    local COMMIT_TITLE=$(echo "$MESSAGE" | sed -E "s/ \([a-f0-9]{7}\)$//; s/ #$PR_NUMBER//; s/ $COMMIT_HASH//; s/ \($TICKET\)//")

    # Prepare the commit and PR links
    local PR_LINK=""
    if [ -n "$PR_NUMBER" ]; then
      PR_URL="$REPO_URL/pull/$PR_NUMBER"
      PR_LINK="[(#$PR_NUMBER)]($PR_URL)"
    fi

    local COMMIT_LINK=""
    if [ -n "$COMMIT_HASH" ]; then
      COMMIT_URL="$REPO_URL/commit/$COMMIT_HASH"
      COMMIT_LINK="[\`$COMMIT_HASH\`]($COMMIT_URL)"
    fi

    # Combine the title and links, removing any duplicate PR links
    local FINAL_COMMIT_MESSAGE="$COMMIT_TITLE $PR_LINK $COMMIT_LINK"
    FINAL_COMMIT_MESSAGE=$(echo "$FINAL_COMMIT_MESSAGE" | sed -E "s/\(#$PR_NUMBER\) \[\(#$PR_NUMBER\)\]/\[\(#$PR_NUMBER\)\]/")

    # Remove the ticket reference from the final message if it still exists
    FINAL_COMMIT_MESSAGE=$(echo "$FINAL_COMMIT_MESSAGE" | sed -E "s/\($TICKET\)//")

    TEMP_CHANGELOG+="  - $FINAL_COMMIT_MESSAGE\n"
  done <<< "$COMMIT_LOG"

  # Write all changes to the changelog file in one go
  echo -e "$TEMP_CHANGELOG" >> $CHANGELOG_FILE

  log_success "Changelog generated and saved to $CHANGELOG_FILE"
}

#!/bin/bash

# Function to merge a feature branch into deploy/test
merge_to_deploy_test() {
  if [ -z "$1" ]; then
    log_error "Usage: merge_to_deploy_test <branch_suffix>"
    return 1
  fi

  # Ensure the prefix for the feature branch
  local TICKET
  TICKET=$(ensure_prefix "$1")
  local BRANCH="feature/$TICKET"

  log "Fetching latest references from remote..."
  git fetch origin || {
    log_error "Failed to fetch remote references."
    return 1
  }

  log "Checking out 'develop' branch..."
  git checkout develop || {
    log_error "Failed to checkout 'develop' branch."
    return 1
  }

  log "Deleting local 'deploy/test' branch if it exists..."
  git branch -D deploy/test 2>/dev/null || log_warning "Local 'deploy/test' branch does not exist."

  log "Creating and checking out 'deploy/test' branch..."
  git checkout -b deploy/test || {
    log_error "Failed to create and checkout 'deploy/test' branch."
    return 1
  }

  log "Merging '$BRANCH' into 'deploy/test'..."
  git merge "$BRANCH" --strategy-option=theirs --no-ff -m "Merge $BRANCH into deploy/test" || {
    log_error "Merge failed. Please resolve conflicts manually."
    return 1
  }

  log "Pushing 'deploy/test' branch to remote..."
  git push --force-with-lease origin deploy/test || {
    log_error "Failed to push 'deploy/test' branch to remote."
    return 1
  }

  log_success "Successfully merged and pushed '$BRANCH' into 'deploy/test'."
}

function get_ticket_info {
  # Check if at least one ticket number was provided
  if [ -z "$1" ]; then
    log_error "Please provide at least one ticket number, separated by commas."
    return 1
  fi

  local TICKET_INPUT="$1"

  # Parse the comma-separated ticket numbers into an array
  local TICKETS
  TICKETS=($(parse_tickets "$TICKET_INPUT"))

  # Get the base Jira URL from Git configuration
  local JIRA_URL
  JIRA_URL=$(git config --get jira.url)

  if [ -z "$JIRA_URL" ]; then
    log_error "JIRA URL is not configured in Git."
    return 1
  fi

  # Get Jira credentials from Git configuration
  local JIRA_EMAIL
  JIRA_EMAIL=$(git config --get jira.email)
  local JIRA_TOKEN
  JIRA_TOKEN=$(git config --get jira.token)

  if [ -z "$JIRA_EMAIL" ] || [ -z "$JIRA_TOKEN" ]; then
    log_error "Jira email or token is not configured in Git."
    return 1
  fi

  # Iterate over each ticket number and fetch its information
  for TICKET_NUMBER in "${TICKETS[@]}"; do
    # Ensure the ticket has the correct prefix, e.g., ATM-867
    local TICKET
    TICKET=$(ensure_prefix "$TICKET_NUMBER")

    # Fetch ticket information from Jira using the API
    local RESPONSE
    RESPONSE=$(safe_curl -s -u "$JIRA_EMAIL:$JIRA_TOKEN" \
      -H "Content-Type: application/json" \
      -X GET "$JIRA_URL/rest/api/2/issue/$TICKET")

    # Clean the JSON response
    RESPONSE=$(clean_json_response "$RESPONSE")

    # Check for errors in the response
    if echo "$RESPONSE" | jq -e '.errorMessages' > /dev/null; then
      log_error "Error fetching ticket $TICKET: $(echo "$RESPONSE" | jq -r '.errorMessages[]')"
      continue
    fi

    # Extract components and format them with brackets, e.g., [VENUS] [WEB]
    local COMPONENTS
    COMPONENTS=$(echo "$RESPONSE" | jq -r '.fields.components[].name' | sed 's/.*/[&]/' | paste -sd' ' -)

    # Extract the ticket summary (title)
    local SUMMARY
    SUMMARY=$(echo "$RESPONSE" | jq -r '.fields.summary')

    # Output the formatted ticket information
    if [ -n "$COMPONENTS" ]; then
      echo "$TICKET: $COMPONENTS - $SUMMARY"
    else
      echo "$TICKET: $SUMMARY"
    fi

    # Construct and display the Jira ticket URL
    echo "$JIRA_URL/browse/$TICKET"
    echo ""  # Add an empty line for better readability
  done
}
