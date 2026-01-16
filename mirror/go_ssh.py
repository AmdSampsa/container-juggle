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

def get_datetime(ssh: paramiko.SSHClient) -> str:
    """Check that datetime is ok in the machine
    
    Returns:
        String containing disk usage information or error message
    """
    stdin, stdout, stderr = ssh.exec_command("date --utc")
    output = stdout.readlines()[0]
    return output

def test_ssh_connection(host_info: Tuple[str, Dict]) -> Tuple[str, str, bool, str, str, str]:
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
    
    print(f"ssh -vvv {config['username']}@{host}")

    try:
        # First test if port is open
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((host, port))
        if result != 0:
            return host, nickname, False, f"Port {port} is closed", "", ""
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
        datetime = get_datetime(ssh)
        # return host, nickname, True, "Connection successful", disk_space
        return host, nickname, True, "", disk_space, datetime
    
    except socket.gaierror:
        return host, nickname, False, "DNS lookup failed", "", ""
    except paramiko.AuthenticationException:
        return host, nickname, False, "Authentication failed", "", ""
    except (socket.timeout, paramiko.SSHException) as e:
        return host, nickname, False, f"Connection failed: {str(e)}", "", ""
    except Exception as e:
        return host, nickname, False, f"Error: {str(e)}", "", ""
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
            host, nickname, success, message, disk_space, datetime = future.result()
            status = "✓" if success else "✗"
            print(f"{status} {nickname} (aka {host}): {message}")
            if disk_space:
                print(f"   Disk Space: {disk_space}")
                # print(f"   UTF time  : {datetime}")
    
    print("-" * 70)

def main():
    parser = argparse.ArgumentParser(
        description="SSH connection utility using YAML config"
    )
    # group = parser.add_mutually_exclusive_group(required=True)
    group = parser
    group.add_argument(
        "-n",
        default=None,
        help="Nickname of the host to connect to"
    )
    group.add_argument(
        "-t", "--test",
        action="store_true",
        help="Test connections to all hosts and show disk space"
    )
    group.add_argument(
        "-c",
        default=None,
        help="Just run a command instead of connecting"
    )
    group.add_argument(
        "--env",
        default=None,
        metavar="HOST",
        help="Output export statements for hostname, sshport, username. Usage: eval $(go_ssh.py --env HOST)"
    )
    
    args = parser.parse_args()
    
    try:
        config = load_config()
    except Exception as e:
        print(f"Error loading config file: {e}")
        sys.exit(1)

    # Handle --env flag
    if args.env is not None:
        if args.env not in config['hosts']:
            print(f"# Error: Host nickname '{args.env}' not found in config", file=sys.stderr)
            sys.exit(1)
        host_config = config['hosts'][args.env]
        print(f'export hostname="{host_config["host"]}"')
        print(f'export sshport="{host_config["sshport"]}"')
        print(f'export username="{config["username"]}"')
        sys.exit(0)

    if args.n is None and args.test:
        test_all_connections(config)
        sys.exit(0)

    if args.n is None:
        print("needs host nickname")
        sys.exit(2)

    if args.n not in config['hosts']:
        print(f"Error: Host nickname '{args.n}' not found in config")
        print("Available hosts:")
        for host in config['hosts'].keys():
            print(f"  {host}")
        sys.exit(1)

    host_config = config['hosts'][args.n]
    username = config['username']
    host = host_config['host']
    port = host_config['sshport']

    print(f"Connecting to {args.n} ({host}) as {username}...")
    
    # Execute SSH command
    ssh_cmd = ['ssh', '-p', str(port), f"{username}@{host}"]
    if args.c:
        ssh_cmd.append(args.c)
    os.execvp('ssh', ssh_cmd)

if __name__ == "__main__":
    main()

