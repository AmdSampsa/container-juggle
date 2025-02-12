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

def get_disk_space(ssh: paramiko.SSHClient) -> str:
    """Get disk space information for root directory.
    
    Returns:
        String containing disk usage information or error message
    """
    try:
        stdin, stdout, stderr = ssh.exec_command("df -h /")
        output = stdout.readlines()
        if len(output) >= 2:  # df output has header and at least one data line
            # Get the last line which contains the actual data
            data = output[1].split()
            total, used, avail = data[1], data[2], data[3]
            used_percent = data[4]
            return f"Total: {total}, Used: {used}, Available: {avail} ({used_percent} used)"
        return "Unable to parse disk space information"
    except Exception as e:
        return f"Error getting disk space: {str(e)}"

def test_ssh_connection(host_info: Tuple[str, Dict]) -> Tuple[str, bool, str, str]:
    """Test SSH connection to a host and check disk space
    
    Args:
        host_info: Tuple of (nickname, host_config)
    
    Returns:
        Tuple of (nickname, success_status, connection_message, disk_space_info)
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
            return nickname, False, f"Port {port} is closed", ""
        sock.close()
        
        # Then try SSH connection
        ssh.connect(
            hostname=host,
            port=port,
            username=config['username'],
            timeout=5
        )
        
        # Get disk space information if connection successful
        disk_space = get_disk_space(ssh)
        return nickname, True, "Connection successful", disk_space
    
    except socket.gaierror:
        return nickname, False, "DNS lookup failed", ""
    except paramiko.AuthenticationException:
        return nickname, False, "Authentication failed", ""
    except (socket.timeout, paramiko.SSHException) as e:
        return nickname, False, f"Connection failed: {str(e)}", ""
    except Exception as e:
        return nickname, False, f"Error: {str(e)}", ""
    finally:
        ssh.close()

def test_all_connections(config):
    """Test connections to all hosts in parallel and show disk space"""
    print("Testing SSH connections and checking disk space...")
    print("-" * 70)
    
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
            nickname, success, message, disk_space = future.result()
            status = "✓" if success else "✗"
            print(f"{status} {nickname}: {message}")
            if disk_space:
                print(f"   Disk Space: {disk_space}")
    
    print("-" * 70)

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
        help="Test connections to all hosts and show disk space"
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

