#!/usr/bin/env python3
"""A short-hand command that uses $HOME/mirror/context/hosts.yaml to connect
to an ssh host. 

Includes also a connection test feature for all hosts.
"""
import sys
import yaml
import os
import subprocess
import argparse
import socket
import paramiko
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, Tuple

# Path to your YAML config file
CONFIG_FILE = f"{os.environ['HOME']}/mirror/context/hosts.yaml"

def load_config():
    with open(CONFIG_FILE, 'r') as f:
        return yaml.safe_load(f)

def test_ssh_connection(host_info: Tuple[str, Dict]) -> Tuple[str, bool, str]:
    """Test SSH connection to a host
    
    Args:
        host_info: Tuple of (nickname, host_config)
    
    Returns:
        Tuple of (nickname, success_status, message)
    """
    nickname, config = host_info
    host = config['host']
    port = config['sshport']
    
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        # First test if port is open
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((host, port))
        if result != 0:
            return nickname, False, f"Port {port} is closed"
        sock.close()
        
        # Then try SSH connection
        ssh.connect(
            hostname=host,
            port=port,
            username=config['username'],
            timeout=5
        )
        ssh.close()
        return nickname, True, "Connection successful"
    
    except socket.gaierror:
        return nickname, False, "DNS lookup failed"
    except paramiko.AuthenticationException:
        return nickname, False, "Authentication failed"
    except (socket.timeout, paramiko.SSHException) as e:
        return nickname, False, f"Connection failed: {str(e)}"
    except Exception as e:
        return nickname, False, f"Error: {str(e)}"
    finally:
        ssh.close()

def test_all_connections(config):
    """Test connections to all hosts in parallel"""
    print("Testing SSH connections to all hosts...")
    print("-" * 50)
    
    host_configs = [
        (nickname, {**host_config, 'username': config['username']})
        for nickname, host_config in config['hosts'].items()
    ]
    
    with ThreadPoolExecutor(max_workers=10) as executor:
        future_to_host = {
            executor.submit(test_ssh_connection, host_info): host_info[0]
            for host_info in host_configs
        }
        
        for future in as_completed(future_to_host):
            nickname, success, message = future.result()
            status = "✓" if success else "✗"
            print(f"{status} {nickname}: {message}")
    
    print("-" * 50)

def main():
    parser = argparse.ArgumentParser(
        description="SSH connection utility using YAML config"
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "host_nickname",
        nargs="?",
        help="Nickname of the host to connect to"
    )
    group.add_argument(
        "-t", "--test",
        action="store_true",
        help="Test connections to all hosts"
    )
    
    args = parser.parse_args()
    
    try:
        config = load_config()
    except Exception as e:
        print(f"Error loading config file: {e}")
        sys.exit(1)

    if args.test:
        test_all_connections(config)
        sys.exit(0)

    if args.host_nickname not in config['hosts']:
        print(f"Error: Host nickname '{args.host_nickname}' not found in config")
        print("Available hosts:")
        for host in config['hosts'].keys():
            print(f"  {host}")
        sys.exit(1)

    host_config = config['hosts'][args.host_nickname]
    username = config['username']
    host = host_config['host']
    port = host_config['sshport']

    print(f"Connecting to {args.host_nickname} ({host}) as {username}...")
    
    # Execute SSH command
    ssh_cmd = ['ssh', '-p', str(port), f"{username}@{host}"]
    os.execvp('ssh', ssh_cmd)

if __name__ == "__main__":
    main()

