#!/usr/bin/env python3
"""
Container System Health Check
------------------------------
Tests critical commands and system components for hanging behavior
before you invest time in a problematic container.

- Safely tests potentially hanging commands like rocminfo
- Validates GPU availability and health 
- Checks other critical system components
- All tests use timeouts to prevent script hanging

Usage: ./container_health_check.py [--timeout SECONDS]
"""

import os
import shutil
import sys
import subprocess
import time
import argparse
import multiprocessing
import signal
import tempfile
import platform
from concurrent.futures import ThreadPoolExecutor, TimeoutError
from pathlib import Path


# Default timeout for command execution (seconds)
DEFAULT_TIMEOUT = 5

class HealthCheck:
    def __init__(self, timeout=DEFAULT_TIMEOUT, verbose=True):
        self.timeout = timeout
        self.verbose = verbose
        self.results = {}
        
    def print(self, msg):
        """Print if verbose mode is enabled"""
        if self.verbose:
            print(msg)
    
    def run_command_safe(self, command, name=None, timeout=None):
        """
        Run a command with timeout safety using multiprocessing to fully isolate
        processes that might hang.
        """
        if name is None:
            name = command[0] if isinstance(command, list) else command.split()[0]
            
        if timeout is None:
            timeout = self.timeout
            
        self.print(f"Testing command: {name}")
        
        # Create a queue for returning results from the process
        queue = multiprocessing.Queue()
        
        # Function to be run in a separate process
        def worker(cmd, q):
            try:
                start_time = time.time()
                result = subprocess.run(
                    cmd, 
                    shell=isinstance(cmd, str),
                    capture_output=True,
                    text=True,
                    timeout=timeout
                )
                elapsed = time.time() - start_time
                q.put({
                    'status': 'success',
                    'exit_code': result.returncode,
                    'stdout': result.stdout,
                    'stderr': result.stderr,
                    'elapsed': elapsed
                })
            except subprocess.TimeoutExpired:
                q.put({'status': 'timeout'})
            except Exception as e:
                q.put({'status': 'error', 'error': str(e)})
        
        # Create and start process
        process = multiprocessing.Process(target=worker, args=(command, queue))
        process.daemon = True  # Allow the process to be terminated when main process exits
        
        start_time = time.time()
        process.start()
        
        # Wait for the result with additional timeout padding
        try:
            result = queue.get(timeout=timeout + 2)
            process.join(1)  # Brief attempt to clean up
        except Exception:
            result = {'status': 'unresponsive'}
        
        # Check if the process is still alive, terminate it if needed
        if process.is_alive():
            self.print(f"Process for {name} didn't exit cleanly, terminating...")
            process.terminate()
            time.sleep(0.5)
            if process.is_alive():
                self.print(f"Process for {name} still alive after terminate, killing...")
                process.kill()
        
        elapsed = time.time() - start_time
        
        # Check for child processes that might still be running
        self.cleanup_orphaned_processes(name)
        
        status = {}
        if result.get('status') == 'success':
            if result['exit_code'] == 0:
                status = {
                    'status': 'passed',
                    'elapsed': result['elapsed'],
                    'details': f"Command completed successfully in {result['elapsed']:.2f}s"
                }
            else:
                status = {
                    'status': 'failed',
                    'exit_code': result['exit_code'],
                    'error': result.get('stderr', ''),
                    'details': f"Command failed with exit code {result['exit_code']}"
                }
        elif result.get('status') == 'timeout':
            status = {
                'status': 'timeout',
                'elapsed': timeout,
                'details': f"Command timed out after {timeout}s"
            }
        elif result.get('status') == 'unresponsive':
            status = {
                'status': 'unresponsive',
                'elapsed': elapsed,
                'details': f"Process became unresponsive after {elapsed:.2f}s"
            }
        else:
            status = {
                'status': 'error',
                'error': result.get('error', 'Unknown error'),
                'details': f"Error: {result.get('error', 'Unknown error')}"
            }
            
        self.results[name] = status
        return status

    def cleanup_orphaned_processes(self, name):
        """Attempt to find and kill any orphaned processes by command name"""
        try:
            # This is a basic implementation - could be enhanced for better detection
            cleanup_cmd = f"pkill -f {name}"
            subprocess.run(cleanup_cmd, shell=True, timeout=2)
        except Exception:
            pass
    
    def test_rocm(self):
        """Test ROCm functionality safely"""
        tests = [
            {
                'name': 'rocminfo',
                'command': 'rocminfo',
                'description': 'Basic ROCm information tool'
            },
            {
                'name': 'rocm-smi',
                'command': 'rocm-smi',
                'description': 'ROCm System Management Interface'
            }
        ]
        
        results = {}
        for test in tests:
            if self.command_exists(test['command']):
                self.print(f"\nTesting {test['name']}: {test['description']}")
                result = self.run_command_safe(test['command'], test['name'])
                
                status_symbol = "✅" if result['status'] == 'passed' else "❌"
                self.print(f"{status_symbol} {test['name']}: {result['status']} - {result['details']}")
                
                results[test['name']] = result
            else:
                self.print(f"⚠️ {test['name']} not found - skipping test")
                
        return results
    
    def test_nvidia(self):
        """Test NVIDIA functionality safely"""
        if self.command_exists('nvidia-smi'):
            self.print("\nTesting NVIDIA GPU:")
            result = self.run_command_safe('nvidia-smi', 'nvidia-smi')
            
            status_symbol = "✅" if result['status'] == 'passed' else "❌"
            self.print(f"{status_symbol} nvidia-smi: {result['status']} - {result['details']}")
            
            return {'nvidia-smi': result}
        else:
            self.print("NVIDIA tools not found - skipping NVIDIA tests")
            return {}
    
    def test_critical_tools(self):
        """Test other critical tools that might hang"""
        tools = [
            'docker',
            'python',
            'gcc',
            'apt-get'
        ]
        
        results = {}
        self.print("\nTesting critical system tools:")
        for tool in tools:
            if self.command_exists(tool):
                # Most tools just need a simple version check
                cmd = f"{tool} --version"
                result = self.run_command_safe(cmd, tool)
                
                status_symbol = "✅" if result['status'] == 'passed' else "❌"
                self.print(f"{status_symbol} {tool}: {result['status']} - {result['details']}")
                
                results[tool] = result
        
        return results
    
    def test_file_system(self):
        """Test filesystem access and performance"""
        self.print("\nTesting filesystem:")
        
        results = {}
        
        # Test temp directory write performance
        with tempfile.TemporaryDirectory() as tmpdir:
            test_file = os.path.join(tmpdir, "test_file")
            
            # Write test
            start = time.time()
            try:
                with open(test_file, "wb") as f:
                    f.write(b"x" * 1024 * 1024 * 10)  # Write 10MB
                write_time = time.time() - start
                
                # Read test
                start = time.time()
                with open(test_file, "rb") as f:
                    f.read()
                read_time = time.time() - start
                
                results['filesystem'] = {
                    'status': 'passed',
                    'details': f"Write: {write_time:.2f}s, Read: {read_time:.2f}s for 10MB",
                    'write_time': write_time,
                    'read_time': read_time
                }
                self.print(f"✅ Filesystem: passed - {results['filesystem']['details']}")
                
            except Exception as e:
                results['filesystem'] = {
                    'status': 'failed',
                    'details': f"Error: {str(e)}"
                }
                self.print(f"❌ Filesystem: failed - {results['filesystem']['details']}")
        
        return results
    
    def command_exists(self, command):
        """Check if a command exists and is executable"""
        return subprocess.run(
            f"command -v {command}",
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        ).returncode == 0
    
    def detect_gpu_type(self):
        """Detect GPU type using both filesystem and command existence checks"""
        # Check for NVIDIA GPUs using nvidia-smi command
        if shutil.which("nvidia-smi") is not None:
            return "NVIDIA"
        
        # Check for AMD GPUs using rocm-smi command
        if shutil.which("rocm-smi") is not None:
            return "AMD"
        
        # Check for Intel GPUs using intel_gpu_top command (if installed)
        if shutil.which("intel_gpu_top") is not None:
            return "Intel"
        
        # Fallback to filesystem checks if commands aren't found
        # Check for AMD GPUs
        if any(Path(p).exists() for p in ['/sys/class/kfd/kfd', '/sys/module/amdgpu']):
            return "AMD"
        
        # Check for NVIDIA GPUs
        if any(Path(p).exists() for p in ['/sys/module/nvidia', '/proc/driver/nvidia']):
            return "NVIDIA"
            
        # Check for Intel GPUs
        if Path('/sys/module/i915').exists():
            return "Intel"
            
        return "Unknown"
    
    def run_all_tests(self):
        """Run all health check tests"""
        self.print(f"=== Container System Health Check ===")
        self.print(f"System: {platform.system()} {platform.release()}")
        self.print(f"Hostname: {platform.node()}")
        self.print(f"Command timeout: {self.timeout} seconds")
        
        gpu_type = self.detect_gpu_type()
        self.print(f"Detected GPU type: {gpu_type}")
        
        # Run appropriate GPU tests
        if gpu_type == "AMD":
            self.test_rocm()
        elif gpu_type == "NVIDIA":
            self.test_nvidia()
            
        # Run other tests
        #self.test_critical_tools()
        #self.test_file_system()
        
        # Print summary
        self.print("\n=== Summary ===")
        passed = sum(1 for r in self.results.values() if r['status'] == 'passed')
        failed = len(self.results) - passed
        
        self.print(f"Tests passed: {passed}/{len(self.results)}")
        
        if failed > 0:
            self.print("\nFailed tests:")
            for name, result in self.results.items():
                if result['status'] != 'passed':
                    self.print(f"❌ {name}: {result['status']} - {result['details']}")
        
        hanging_commands = [name for name, result in self.results.items() 
                          if result['status'] in ('timeout', 'unresponsive')]
        
        if hanging_commands:
            self.print("\n⚠️ WARNING: The following commands appear to hang and should be avoided:")
            for cmd in hanging_commands:
                self.print(f"  - {cmd}")
            
            self.print("\nRecommendation: Add the following to your .bashrc to avoid hanging:")
            self.print(f"# Skip commands known to hang in this container")
            for cmd in hanging_commands:
                self.print(f"alias {cmd}='echo \"WARNING: {cmd} is known to hang in this container\"'")
        
        return {
            'passed': passed,
            'failed': failed,
            'total': len(self.results),
            'hanging_commands': hanging_commands,
            'results': self.results
        }


def main():
    parser = argparse.ArgumentParser(description="Container System Health Check")
    parser.add_argument('--timeout', type=int, default=DEFAULT_TIMEOUT,
                      help=f'Command timeout in seconds (default: {DEFAULT_TIMEOUT})')
    parser.add_argument('--quiet', action='store_true',
                      help='Reduce output verbosity')
    args = parser.parse_args()
    
    checker = HealthCheck(timeout=args.timeout, verbose=not args.quiet)
    results = checker.run_all_tests()
    
    # Return non-zero exit code if any tests failed
    sys.exit(1 if results['failed'] > 0 else 0)

if __name__ == "__main__":
    main()

