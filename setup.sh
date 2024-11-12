#!/bin/bash

# Source the logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

# Detect the shell profile file to append based on OS and shell type
PROFILE_PATH=""

# Detect the OS and shell profile
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if [[ -n "$ZSH_VERSION" ]]; then
        PROFILE_PATH="$HOME/.zshrc"
    else
        PROFILE_PATH="$HOME/.bashrc"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if [[ -n "$ZSH_VERSION" ]]; then
        PROFILE_PATH="$HOME/.zshrc"
    else
        PROFILE_PATH="$HOME/.bash_profile"
    fi
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # Windows (Git Bash)
    PROFILE_PATH="$HOME/.bash_profile"
fi

# Set up the project path as a variable
export TC_SCRIPTS_PATH="$SCRIPT_DIR"
MAIN_SCRIPT="\${TC_SCRIPTS_PATH}/main.sh"

# Add execute permissions to all scripts
log "Setting execute permissions for all scripts in the project..."
chmod +x "$TC_SCRIPTS_PATH"/*.sh
log_success "Permissions set successfully."

# Define commands to be added in the profile file using variable names
EXPORT_CMD="export TC_SCRIPTS_PATH=\"$TC_SCRIPTS_PATH\""
SOURCE_CMD="source $MAIN_SCRIPT"
RELOAD_CMD="reloadScripts() { source \${PROFILE_PATH}; }; alias rs=reloadScripts"
CD_SCRIPTS_CMD="cdScripts() { cd \${TC_SCRIPTS_PATH}; }; alias cds=cdScripts"
EXPORT_PROFILE_CMD="export PROFILE_PATH=\"$PROFILE_PATH\""

# Check if TC_SCRIPTS_PATH is already exported
if grep -Fxq "$EXPORT_CMD" "$PROFILE_PATH"; then
    log "The TC_SCRIPTS_PATH is already set in $PROFILE_PATH"
else
    # Add the export command for TC_SCRIPTS_PATH first
    echo -e "\n\n# Export tc-scripts project path\n$EXPORT_CMD" >> "$PROFILE_PATH"
    log "Added TC_SCRIPTS_PATH export to $PROFILE_PATH"
fi

# Check if PROFILE_PATH is already exported
if grep -Fxq "$EXPORT_PROFILE_CMD" "$PROFILE_PATH"; then
    log "The PROFILE_PATH is already set in $PROFILE_PATH"
else
    # Add the export command for PROFILE_PATH
    echo -e "\n# Export shell profile path\n$EXPORT_PROFILE_CMD" >> "$PROFILE_PATH"
    log "Added PROFILE_PATH export to $PROFILE_PATH"
fi

# Check if the sourcing command is already in the profile
if grep -Fxq "$SOURCE_CMD" "$PROFILE_PATH"; then
    log "The tc-scripts are already sourced in $PROFILE_PATH"
else
    # Add the sourcing command
    echo -e "\n# Source tc-scripts main script\n$SOURCE_CMD" >> "$PROFILE_PATH"
    log "Added tc-scripts sourcing command to $PROFILE_PATH"
fi

# Check if the reload command is in the profile
if grep -Fxq "reloadScripts()" "$PROFILE_PATH"; then
    log "The reload function 'reloadScripts' is already in $PROFILE_PATH"
else
    # Add reload command and alias
    echo -e "\n# Function and alias to reload tc-scripts\n$RELOAD_CMD" >> "$PROFILE_PATH"
    log "Added reload function 'reloadScripts' and alias 'rs' to $PROFILE_PATH"
fi

# Check if the cdScripts command is in the profile
if grep -Fxq "cdScripts()" "$PROFILE_PATH"; then
    log "The 'cdScripts' function is already in $PROFILE_PATH"
else
    # Add cdScripts function and alias
    echo -e "\n# Function and alias to change directory to tc-scripts\n$CD_SCRIPTS_CMD" >> "$PROFILE_PATH"
    log "Added 'cdScripts' function and alias 'cds' to $PROFILE_PATH"
fi

# Source the profile to make sure everything is loaded
source "$PROFILE_PATH"

# Use success log to show if it works
log_success "Setup complete! The tc-scripts are now available in your terminal."
