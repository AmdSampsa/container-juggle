#!/bin/bash
## fetch someone else's repo & branch
## usage: fetch-branch.sh repo-name username branchname
##

# Check if all arguments are provided
if [ $# -ne 3 ]; then
    echo "Usage: $0 repo-name username branchname"
    exit 1
fi

echo "Current origin: $(git remote get-url origin)"

# Check if the remote already exists
if git remote | grep -q "^$2$"; then
    echo "Remote '$2' already exists, updating URL..."
    git remote set-url $2 https://github.com/$2/$1.git
else
    echo "Adding remote '$2'..."
    git remote add $2 https://github.com/$2/$1.git
fi

# Fetch the branch from the remote
echo "Fetching branch '$3' from $2..."
git fetch $2 $3:$3

# Checkout the branch
echo "Checking out branch '$3'..."
git checkout $3

echo "Done! You are now on branch '$3'"
