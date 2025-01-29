#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

def get_test_paths(test_file=None):
    # Build pytest command
    cmd = ['pytest', '--collect-only', '-v']
    if test_file:
        cmd.append(str(test_file))
    
    # Run pytest and capture output
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
    except Exception as e:
        print(f"Error running pytest: {e}", file=sys.stderr)
        sys.exit(1)
    
    if result.returncode != 0:
        print(f"Error collecting tests:\n{result.stderr}", file=sys.stderr)
        sys.exit(1)
    
    # Process lines and extract test paths
    test_paths = []
    for line in result.stdout.split('\n'):
        if '<' in line or not '::' in line:  # Skip non-test lines
            continue
        # Clean up the line to get just the test path
        path = line.strip().split('[')[0].strip()
        if path:
            test_paths.append(path)
    
    return test_paths

if __name__ == '__main__':
    # Simple argument handling
    test_file = sys.argv[1] if len(sys.argv) > 1 else None
    
    if test_file:
        file_path = Path(test_file)
        if not file_path.exists():
            print(f"Error: File {test_file} does not exist", file=sys.stderr)
            sys.exit(1)
    
    print("\nCopyable test paths:")
    print("-" * 40)
    for path in get_test_paths(test_file):
        print(path)
    print("\nYou can run individual tests with:")
    print("pytest path::to::test")
    