#!/bin/bash
##
## NOTE: you can use this always when syncing your pytorch main with the upstream main
## not just for the first time git checkout
## 
## however, it's better to run clean_torch.bash first
##
# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ORIGINAL_REPO="https://github.com/pytorch/pytorch.git"
YOUR_BRANCH="main"
ORIGINAL_BRANCH="main"

# since="4 weeks ago"
since="2 years ago ago"

echo
echo Getting latest pytorch main from YOUR repo $gituser
echo Will also sync your repo with the latest upstream pytorch
echo
#read -p "press any key to continue.."
# echo
# cd $HOME
# git clone git@github.com:$gituser/pytorch.git $HOME/pytorch-me
# git clone --shallow-since="$since" git@github.com:$gituser/pytorch.git $HOME/pytorch-me
# NOTE: you can always git fetch --unshallow
# cd $HOME/pytorch-me

if [ -d "$HOME/pytorch-me" ]; then
    echo "Directory $HOME/pytorch-me already exists, skipping clone."
    # Optionally change to the directory
else
    echo "Cloning repository..."
    git clone --shallow-since="$since" git@github.com:$gituser/pytorch.git "$HOME/pytorch-me"
fi
cd $HOME/pytorch-me

# Check for existing remotes
if ! git remote | grep -q "^upstream$"; then
  echo -e "${YELLOW}Upstream remote not found. Adding it now...${NC}"
  git remote add upstream "$ORIGINAL_REPO"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to add upstream remote.${NC}"
    exit 1
  fi
  echo -e "${GREEN}Upstream remote added successfully.${NC}"
else
  echo -e "${GREEN}Upstream remote already exists.${NC}"
fi

# Fetch the latest from upstream
echo -e "\n${BLUE}Fetching latest changes from upstream...${NC}"
git fetch --shallow-since="$since" upstream main
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to fetch from upstream.${NC}"
  exit 1
fi

# Make sure we're on our main branch
echo -e "\n${BLUE}Checking out your $YOUR_BRANCH branch...${NC}"
git checkout "$YOUR_BRANCH"
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to checkout $YOUR_BRANCH branch.${NC}"
  exit 1
fi

# Get current branch status
BRANCH_STATUS=$(git status -s)
if [ -n "$BRANCH_STATUS" ]; then
  echo -e "${YELLOW}Warning: You have uncommitted changes on your $YOUR_BRANCH branch.${NC}"
  echo -e "Consider committing or stashing these changes before syncing."
  
  # Show the current changes
  echo -e "\n${BLUE}Current changes:${NC}"
  git status -s
  
  # Ask for confirmation
  read -p "Continue with sync anyway? [y/N] " CONTINUE
  if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Sync aborted.${NC}"
    exit 0
  fi
fi

# Merge upstream changes
echo -e "\n${BLUE}Merging changes from upstream/$ORIGINAL_BRANCH into your $YOUR_BRANCH branch...${NC}"
git merge "upstream/$ORIGINAL_BRANCH"
if [ $? -ne 0 ]; then
  echo -e "${RED}Merge conflict! Please resolve the conflicts manually.${NC}"
  echo "After resolving conflicts, complete the merge with 'git merge --continue'"
  echo "and push changes with 'git push origin $YOUR_BRANCH'"
  exit 1
fi

# Push changes to origin
echo -e "\n${BLUE}Pushing changes to your fork...${NC}"
git push origin "$YOUR_BRANCH"
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to push to origin.${NC}"
  exit 1
fi

echo -e "\n${GREEN}✓ Successfully synced your fork with upstream.${NC}"

echo
#cd pytorch
#echo "Status:"
#git remote -v
#echo
