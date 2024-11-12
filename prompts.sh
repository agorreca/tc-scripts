cat << 'EOF' > prompts.sh
#!/bin/bash

# Source all prompt files
PROMPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/prompts" && pwd)"

for prompt_file in "$PROMPTS_DIR"/*.sh; do
  source "$prompt_file"
done
EOF
