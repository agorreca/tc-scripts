# TC-Scripts 🚀

This project is a collection of modular shell scripts for automating various tasks and workflows, organized for easy management and reuse. Each function is split into specific modules and can be used from any terminal. Ideal for developers looking to streamline their workflow with Git, GitHub, Jira, and more.

---

## ⚙️ Setup Instructions

To get started, follow these steps to set up the project on your system.

### 1️⃣ Clone the Repository

Clone the repository into the desired directory, for example:

```
git clone <repository_url> /c/work/tc-scripts
```

### 2️⃣ Run the Setup Script

Run the `setup.sh` script to configure the environment by automatically adding the `source` command to your profile file (`~/.bash_profile`, `~/.bashrc`, or `~/.zshrc` depending on your system):

```
cd /c/work/tc-scripts
bash setup.sh
```

The setup script will detect your operating system and append the sourcing command to the appropriate profile file. After running the script, reload your profile by running:

```
source ~/.bash_profile   # or ~/.bashrc or ~/.zshrc based on your system
```

This will make the commands and functions from the scripts available in your terminal.

### 3️⃣ Verify Installation

You can verify that the commands are accessible by running any of the defined aliases or functions, such as `smartpush`, to confirm the setup.

---

## 📂 Project Structure

Below is the project structure, with each script handling a specific type of functionality:

```
/tc-scripts
├── main.sh                   # Main script to source all modules
├── logging.sh                # Logging functions (info, success, error, etc.)
├── utils.sh                  # General utility functions
├── git_functions.sh          # Git-related functions
├── jira_functions.sh         # Jira-related functions
├── github_functions.sh       # GitHub-related functions
├── google_chat.sh            # Google Chat integration functions
├── prompts/                  # Folder containing prompt templates
│   ├── diff_to_commit_msg.sh
│   ├── commit_message_example.sh
│   ├── generate_tests_prompt.sh
│   ├── fix_tests_prompt.sh
│   └── subtask_prompt.sh
└── setup.sh                  # Installation and configuration script
```

### 🧩 Modules and Scripts

Each file in the project has a specific purpose:

- **`main.sh`**: The main entry point that sources all other modules, making them available in the terminal.
- **`logging.sh`**: Contains various logging functions to output messages with colors (e.g., `log`, `log_warning`, `log_error`, `log_success`, etc.).
- **`utils.sh`**: General-purpose utility functions used across other modules.
- **`git_functions.sh`**: All Git-related functions such as creating commits, branches, and managing PRs.
- **`jira_functions.sh`**: Functions for interacting with Jira tickets, transitions, and comments.
- **`github_functions.sh`**: Functions for creating and managing GitHub PRs, approvals, and notifications.
- **`google_chat.sh`**: Functions to post messages and notifications to Google Chat.
- **`prompts/`**: Directory containing prompt templates used in various functions.
- **`setup.sh`**: Script to configure and install the sourcing command in the user’s shell profile.

---

## ➕ Adding New Functions

To add a new function, create a new file or add to an existing one based on its type. For example:

1. **To add a Git function**, edit `git_functions.sh`.
2. **For a new prompt template**, create a new file in the `prompts/` directory.

Make sure to test any new functions by sourcing `main.sh` and running them in the terminal.

---

## 🔄 Updating the Profile with `setup.sh`

If you move the project directory or need to reconfigure the setup, rerun the `setup.sh` script. It will update your profile with the correct path to `main.sh` and set up the necessary aliases and environment variables.

---

## 💡 Usage Example

With the setup complete, you can now use the provided aliases and functions directly from the terminal. Here’s a basic example:

```
# Example: Create a commit and a pull request
smartpush "JIRA-123"
```

This will trigger the `createCommitAndPRs` function with your Jira ticket ID, streamlining the entire workflow from creating a commit message to pushing and creating a PR.

---

## 🛠️ Additional Commands

### 🔁 Reload Scripts

To reload the TC-Scripts configuration without restarting your terminal, use:

```
rs
```

### 📁 Change to Scripts Directory

To quickly navigate to the scripts directory, use:

```
cdScripts
```

---

## 🛠️ Troubleshooting

- **Commands Not Found**: Ensure that the sourcing command (`source /path/to/main.sh`) was added to your profile file (`~/.bash_profile`, `~/.bashrc`, or `~/.zshrc`). After making changes to these files, always reload them with `source ~/.bash_profile`.

- **Script Errors**: If you encounter any errors, verify that all required dependencies, such as `jq`, `curl`, and `git`, are installed and available in your `$PATH`.

---

## 📜 License

This project is open-source. Feel free to modify and distribute it according to your needs.
