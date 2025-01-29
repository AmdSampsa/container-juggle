#!/usr/bin/env python3
import json, os
import base64
import argparse


# TODO: different workspace templates.. nightly or amd also python version.. maybe automate, based on image name?
"""
nightly-workspace = {
    "folders": [
        {
            "uri": f"vscode-remote://{container_uri}/root"
        },
        {
            "uri": f"vscode-remote://{container_uri}/opt/conda/envs/py_3.10/lib/python3.10/site-packages/torch"
        },
        {
            "uri": f"vscode-remote://{container_uri}/tmp/pytorch"
        }
    ],
    "remoteAuthority": container_uri,
    "settings": {}
}

amd-workspace = {
    "folders": [
        {
            "uri": f"vscode-remote://{container_uri}/root"
        },
        {
            "uri": f"vscode-remote://{container_uri}/opt/conda/envs/py_3.10/lib/python3.10/site-packages/torch"
        },
        {
            "uri": f"vscode-remote://{container_uri}/tmp/pytorch"
        }
    ],
    "remoteAuthority": container_uri,
    "settings": {}
}
"""

def create_container_uri(container_name, ssh_remote):
    """Create the container URI component."""
    # Create the container JSON and encode it
    container_json = json.dumps({"containerName": container_name})
    container_hex = container_json.encode('utf-8').hex()
    
    # Combine into full URI prefix
    return f"attached-container+{container_hex}@ssh-remote+{ssh_remote}"

def create_workspace_json(container_name, ssh_remote):
    """Create the full workspace JSON structure."""
    container_uri = create_container_uri(container_name, ssh_remote)
    
    workspace = {
        "folders": [
            {
                "uri": f"vscode-remote://{container_uri}/root"
            },
            {
                "uri": f"vscode-remote://{container_uri}/opt/conda/envs/py_3.10/lib/python3.10/site-packages/torch"
            },
            {
                "uri": f"vscode-remote://{container_uri}/tmp/pytorch"
            }
        ],
        "remoteAuthority": container_uri,
        "settings": {}
    }
    
    return workspace

def main():
    parser = argparse.ArgumentParser(description='Generate VS Code workspace file for Docker container')
    parser.add_argument('--container_name', help='Name of the Docker container', default = os.environ["container_name"])
    parser.add_argument('--ssh-remote', help='SSH remote host nickname', default = os.environ["container_name"])
    parser.add_argument('--output', default=os.path.join(os.environ["HOME"], "wrkspaces", f"{os.environ['contextname']}.code-workspace"),
        help='Output filename')
    
    args = parser.parse_args()
    
    workspace = create_workspace_json(args.container_name, args.ssh_remote)
    
    with open(args.output, 'w') as f:
        json.dump(workspace, f, indent=8)
    
    print(f"Workspace file created: {args.output}")

if __name__ == "__main__":
    main()
