#!/bin/bash
echo
echo This script is used for rocm images where you already have
echo a pytorch repo checkd out
echo
read -p "press any key to continue.."
echo
# Loop through each remote
for remote in $(git remote); do
    # Get the URL for this remote
    url=$(git remote get-url $remote)
    
    # Convert HTTPS to SSH format
    if [[ $url == https://github.com/* ]]; then
        # Extract the repository path
        repo_path=$(echo "$url" | sed 's|https://github.com/||')
        # Create new SSH URL
        ssh_url="git@github.com:$repo_path"
        
        echo "Converting $remote from $url to $ssh_url"
        git remote set-url $remote "$ssh_url"
    else
        echo "Remote $remote URL is not a GitHub HTTPS URL: $url"
    fi
done

echo -e "\nUpdated remotes"
echo "Will add a push address to your personal fork of the pytorch repo"
git remote add fork git@github.com:$gituser/pytorch.git
echo
echo "Status:"
git remote -v
echo
echo "setting gh default repo"
gh repo set-default pytorch/pytorch
echo
echo "for pushing, use:"
echo "git push --set-upstream fork BRANCH"
echo

