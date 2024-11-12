cat << 'EOF' > prompts/subtask_prompt.sh
#!/bin/bash

SUBTASK_PROMPT="Create the task title and a brief description of the task that outputs the given diff,
as if it hasn't been started yet. The task title should be in sentence case.
Do not mention the diff explicitly. The description should be a single paragraph.
Do not use simple quotes (single or double) to prevent escaping errors."
EOF
