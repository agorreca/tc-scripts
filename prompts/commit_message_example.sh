cat << 'EOF' > prompts/commit_message_example.sh
#!/bin/bash

COMMIT_MESSAGE_EXAMPLE=":sparkles: feat(ATM-120): complete WorkstreamStatus component and add new status icons

- Finalized the implementation of the WorkstreamStatus component:
  - Added dynamic workstream selection
  - Displayed workstream statuses
  - Implemented detailed view for each workstream
- Added new SVG icons for various statuses:
  - done
  - undone
- Removed an unused import from the Snackbar component"
EOF
