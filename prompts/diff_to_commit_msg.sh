cat << 'EOF' > prompts/diff_to_commit_msg.sh
#!/bin/bash

DIFF_TO_COMMIT_MSG_PROMPT="Given the following diff, generate a conventional commit message (with type, scope, description, body).
The title should follow the format '<emoji> <type>(%s): <description>' or ':rotating_light: <type>(%s)!: <description>' for breaking changes.
Write it in simple English and in a markdown formatted text block without using triple backticks, except for the first and last.
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
EOF
