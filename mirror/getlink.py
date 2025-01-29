#!/usr/bin/env python3
import subprocess
import re
import sys
"""Example usage:

Just run this in a directory that has a git repo on the desired branch.

It will give the url / github link for the commit
"""
def get_git_status():
    """Get the current git status output."""
    result = subprocess.run(['git', 'status'], capture_output=True, text=True)
    return result.stdout

def get_remote_url():
    """Get the GitHub remote URL."""
    result = subprocess.run(['git', 'remote', 'get-url', 'origin'], 
                          capture_output=True, text=True)
    url = result.stdout.strip()
    # Convert SSH URL to HTTPS URL if necessary
    ssh_match = re.match(r'git@github\.com:(.+?)(?:\.git)?$', url)
    if ssh_match:
        return f"https://github.com/{ssh_match.group(1)}"
    # Clean up HTTPS URL if necessary
    https_match = re.match(r'https://github\.com/(.+?)(?:\.git)?$', url)
    if https_match:
        return f"https://github.com/{https_match.group(1)}"
    return url

def get_current_commit():
    """Get the current commit hash."""
    result = subprocess.run(['git', 'rev-parse', 'HEAD'], 
                          capture_output=True, text=True)
    return result.stdout.strip()

def get_current_branch():
    """Get the current branch name."""
    result = subprocess.run(['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                          capture_output=True, text=True)
    return result.stdout.strip()

def main():
    try:
        status = get_git_status()
        repo_url = get_remote_url()
        branch_name = get_current_branch()

        # Check if we're on a PR branch
        pr_match = re.search(r'On branch pr-(\d+)', status)
        if pr_match:
            pr_number = pr_match.group(1)
            print()
            print(f"{repo_url}/pull/{pr_number}")
            print()
        else:
            # Get the commit hash
            commit_hash = get_current_commit()
            print()
            print(f"{repo_url}/commit/{commit_hash}")
            print()
            print(f"{repo_url}/tree/{commit_hash}")
            print()
            print(f"{repo_url}/tree/{branch_name}")
            print()

            
    except subprocess.CalledProcessError as e:
        print(f"Error executing git command: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
