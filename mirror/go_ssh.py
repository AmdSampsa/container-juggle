#!/usr/bin/env python3
"""A short-hand command that uses $HOME/mirror/context/hosts.yaml to connect
to an ssh host.
"""
import sys
import yaml
import os
import subprocess

# Path to your YAML config file
CONFIG_FILE = f"{os.environ['HOME']}/mirror/context/hosts.yaml"

def load_config():
    with open(CONFIG_FILE, 'r') as f:
        return yaml.safe_load(f)

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} host-nickname")
        sys.exit(1)

    host_nickname = sys.argv[1]
    
    try:
        config = load_config()
    except Exception as e:
        print(f"Error loading config file: {e}")
        sys.exit(1)

    if host_nickname not in config['hosts']:
        print(f"Error: Host nickname '{host_nickname}' not found in config")
        print("Available hosts:")
        for host in config['hosts'].keys():
            print(f"  {host}")
        sys.exit(1)

    host_config = config['hosts'][host_nickname]
    username = config['username']
    host = host_config['host']
    port = host_config['sshport']

    print(f"Connecting to {host_nickname} ({host}) as {username}...")
    
    # Execute SSH command
    ssh_cmd = ['ssh', '-p', str(port), f"{username}@{host}"]
    os.execvp('ssh', ssh_cmd)

if __name__ == "__main__":
    main()
