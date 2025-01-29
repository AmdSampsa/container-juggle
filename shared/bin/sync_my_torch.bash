#!/bin/bash

# Function to pause and wait for user input
pause() {
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    echo
    echo
}

# Function to print stage information
print_stage() {
    echo "================================================================="
    echo "$1"
    echo "================================================================="
}

# Clear the screen to start fresh
clear

print_stage "Stage 0: Checking remotes"
echo "Checking for required remote 'fork'..."
if ! git remote | grep -q "^fork$"; then
    echo "ERROR: Remote 'fork' not found! Please set up your fork remote first."
    echo "You can add it with: git remote add fork git@github.com:YOUR_USERNAME/pytorch.git"
    exit 1
fi
echo "Remote 'fork' found. Current remotes:"
git remote -v
pause

print_stage "Stage 1: Fetching latest changes from upstream (origin)"
echo "About to run: git fetch origin"
pause
git fetch origin
echo "Fetch completed."

print_stage "Stage 2: Checking out main branch"
echo "About to run: git checkout main"
pause
git checkout main
echo "Now on main branch."

print_stage "Stage 3: Rebasing with origin/main"
echo "About to run: git rebase origin/main"
pause
git rebase origin/main
echo "Rebase completed."

print_stage "Stage 4: Force pushing to fork"
echo "About to run: git push --force-with-lease fork main"
echo "WARNING: This will force push to your fork. Make sure this is what you want!"
pause
git push --force-with-lease fork main
echo "Push completed."

print_stage "Sync completed!"
echo "Your fork should now be up to date with the upstream repository."
echo "If you see any errors above, please review them carefully."

#
# rebase a certain branch to origin/main:
# 
## First make sure we have the latest from origin
#git fetch origin
##
## Now rebase skip-l1-cache onto origin/main
#git rebase origin/main skip-l1-cache
##
## Since this branch exists on your fork and you're rewriting history, 
## you'll need to force push it back
#git push --force-with-lease fork skip-l1-cache
#
