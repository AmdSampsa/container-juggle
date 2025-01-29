#!/usr/bin/python3
import argparse
import yaml
import os
import sys
import subprocess
from pathlib import Path

def run_with_context(script_to_run, ssh=False, only=None):
    # Get yaml path using pathlib
    yaml_file = Path.home() / "mirror" / "context" / "hosts.yaml"
    
    if not yaml_file.exists():
        print(f"Error: {yaml_file} not found")
        sys.exit(1)
        
    try:
        with open(yaml_file, 'r') as f:
            config = yaml.safe_load(f)
    except yaml.YAMLError as e:
        print(f"Error parsing YAML file: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading file: {e}")
        sys.exit(1)
    
    # Validate YAML structure
    if 'username' not in config:
        print("Error: 'username' not found in YAML file")
        sys.exit(1)
    if 'hosts' not in config:
        print("Error: 'hosts' not found in YAML file")
        sys.exit(1)
        
    username = config['username']
    
    # For each hostname in the config
    for hostnick, host_config in config['hosts'].items():
        print(f"\nProcessing host: {hostnick}")

        if only and (hostnick != only):
            print("skipping host", hostnick)
            continue

        if host_config.get("skip", False):
            print("skipping host", hostnick)
            continue

        if 'sshport' not in host_config:
            print(f"Error: 'sshport' not found for host {hostname}")
            continue
            
        sshport = host_config['sshport']
        hostname = host_config["host"]
        
        # Set environment variables
        os.environ['username'] = username
        os.environ['hostname'] = hostname
        os.environ['sshport'] = str(sshport)
        
        if ssh:
            # 'bash -ic "echo \"Hello World\""'
            script_to_run_ = f"ssh -q -o LogLevel=QUIET -p{sshport} {username}@{hostname} {script_to_run} 2>/dev/null"
            print(">", script_to_run_)
            # script_to_run_ = f"ssh -q -p{sshport} {username}@{hostname} 'source ~/.bashrc && {script_to_run}'"
            # print(script_to_run_)
        else:
            script_to_run_ = script_to_run

        try:
            # Run the script
            subprocess.run([script_to_run_], shell=True, check=True)
        except subprocess.CalledProcessError as e:
            print(f"Error running script for host {hostname}: {e}")
        except Exception as e:
            print(f"Unexpected error for host {hostname}: {e}")

        print("did host", hostnick)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="""
Default behaviour: changes environmental variables in a loop for (username, hostname, sshport) and for each loop value,
run the desired command (that supposedly uses those env vars).

Typical use case: pushremove.bash

If --ssh is used, then run an ssh command in each host instead.

Typical use case: run our helper scripts in the remote host: getgpu.bash or for example "tmux kill-server"

If your command includes spaces, use this kind of comma encapsulation:

run_all_hosts.py --ssh '"ls ~/mirror/.git"'

""")
    parser.add_argument('script_to_run', help='The script to run')
    # parser.add_argument('script_to_run', nargs='...', help='The script to run')
    parser.add_argument("--only", action='store', default=None)
    parser.add_argument('--ssh', action='store_true', help='Run the command via SSH')
    args = parser.parse_args()
    run_with_context(args.script_to_run, ssh=args.ssh, only=args.only)
