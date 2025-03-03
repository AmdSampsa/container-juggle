#!/bin/bash
# Script to run lintrunner on recently committed or staged files

set -e

show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo "Run lintrunner on recently committed or staged files."
  echo
  echo "Options:"
  echo "  -c, --committed     Run lintrunner on files from the most recent commit (default)"
  echo "  -s, --staged        Run lintrunner on currently staged files"
  echo "  -n, --dry-run       Don't run lintrunner, just print the files"
  echo "  -h, --help          Show this help message"
  echo
  echo "Example: $0 --staged"
}

# Default values
MODE="committed"
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--committed)
      MODE="committed"
      shift
      ;;
    -s|--staged)
      MODE="staged"
      shift
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

get_committed_files() {
  # Get files from the most recent commit
  git show --name-only --format="" | grep -v "^$"
}

get_staged_files() {
  # Get files currently staged for commit
  git diff --staged --name-only
}

# Get the list of files based on the mode
if [[ "$MODE" == "committed" ]]; then
  echo "Getting files from the most recent commit..."
  FILES=$(get_committed_files)
else
  echo "Getting staged files..."
  FILES=$(get_staged_files)
fi

# Check if we have any files
if [[ -z "$FILES" ]]; then
  echo "No files found."
  exit 0
fi

# Convert files list to array
# IFS=$'\n' read -d '' -ra FILE_ARRAY <<< "$FILES"
readarray -t FILE_ARRAY <<< "$FILES"

# echo $IFS

# Print the files
echo "Files to lint:"
for file in "${FILE_ARRAY[@]}"; do
  echo "  - $file"
done

# Exit if dry run
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run - not running lintrunner."
  exit 0
fi

# Run lintrunner on the files
echo "Running lintrunner..."
echo "${FILE_ARRAY[@]}" | xargs ./venv/bin/lintrunner -a 

echo "Done!"
