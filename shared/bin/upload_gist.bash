#!/bin/bash

# Script to upload a file to GitHub Gist
# Usage: upload_gist.bash FILENAME [--fname filename_in_gist] [--secret] [--comment "description"]

set -e

# Default values
SECRET=false
GIST_FILENAME=""
GIST_DESCRIPTION=""

# Parse arguments
SOURCE_FILE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --fname)
            GIST_FILENAME="$2"
            shift 2
            ;;
        --secret)
            SECRET=true
            shift
            ;;
        --comment)
            GIST_DESCRIPTION="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 FILENAME [--fname filename_in_gist] [--secret] [--comment \"description\"]" >&2
            exit 1
            ;;
        *)
            if [[ -z "$SOURCE_FILE" ]]; then
                SOURCE_FILE="$1"
            else
                echo "Error: Multiple files specified. Only one file allowed." >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if source file is provided
if [[ -z "$SOURCE_FILE" ]]; then
    echo "Error: FILENAME is required" >&2
    echo "Usage: $0 FILENAME [--fname filename_in_gist] [--secret] [--comment \"description\"]" >&2
    exit 1
fi

# Check if source file exists
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Error: File '$SOURCE_FILE' does not exist" >&2
    exit 1
fi

# Check for GitHub token
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Error: GITHUB_TOKEN environment variable is not set" >&2
    echo "Please set it with: export GITHUB_TOKEN=your_token_here" >&2
    exit 1
fi

# Determine gist filename (use --fname if provided, otherwise use basename of source file)
if [[ -z "$GIST_FILENAME" ]]; then
    GIST_FILENAME=$(basename "$SOURCE_FILE")
fi

# Set default description if not provided
if [[ -z "$GIST_DESCRIPTION" ]]; then
    GIST_DESCRIPTION="Uploaded via upload_gist.bash"
fi

# Read file content and escape for JSON
FILE_CONTENT=$(cat "$SOURCE_FILE" | jq -Rs .)

# Create JSON payload
if [[ "$SECRET" == "true" ]]; then
    PUBLIC="false"
else
    PUBLIC="true"
fi

JSON_PAYLOAD=$(jq -n \
    --arg filename "$GIST_FILENAME" \
    --arg description "$GIST_DESCRIPTION" \
    --argjson content "$FILE_CONTENT" \
    --argjson public "$PUBLIC" \
    '{
        description: $description,
        public: ($public == "true"),
        files: {
            ($filename): {
                content: $content
            }
        }
    }')

# Upload to GitHub Gist
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" \
    https://api.github.com/gists)

# Extract HTTP status code (last line)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

# Check if request was successful
if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    # Extract HTML URL from response
    GIST_URL=$(echo "$BODY" | jq -r '.html_url')
    if [[ "$GIST_URL" != "null" && -n "$GIST_URL" ]]; then
        echo "$GIST_URL"
        exit 0
    else
        echo "Error: Failed to extract gist URL from response" >&2
        echo "Response: $BODY" >&2
        exit 1
    fi
else
    echo "Error: Failed to create gist (HTTP $HTTP_CODE)" >&2
    echo "Response: $BODY" >&2
    exit 1
fi
