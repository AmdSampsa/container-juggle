#!/usr/bin/env python3
import argparse
import subprocess
import sys
from pathlib import Path
import yaml
from typing import Dict, List, Optional

class TestRunner:
    def __init__(self, config_file: str, format_type: str = 'auto'):
        self.config = self._load_config(config_file, format_type)
        
    def _load_config(self, config_file: str, format_type: str = 'auto') -> Dict:
        """Load and parse the test configuration file.
        
        Args:
            config_file: Path to the configuration file
            format_type: One of 'auto', 'yaml', 'indent', or 'table'
        """
        with open(config_file, 'r') as f:
            if format_type == 'yaml' or (format_type == 'auto' and config_file.endswith(('.yaml', '.yml'))):
                return yaml.safe_load(f)
            elif format_type == 'table' or (format_type == 'auto' and '\t' in f.readline()):
                f.seek(0)  # Reset file pointer after readline
                return self._parse_table_format(f)
            else:
                f.seek(0)  # Reset file pointer
                return self._parse_indent_format(f)
    
    def _parse_table_format(self, file) -> Dict:
        """Parse tab-separated table format."""
        config = {}
        for line in file:
            line = line.strip()
            if not line or line.startswith('#'):  # Skip empty lines and full-line comments
                continue
                
            # Remove end-of-line comments if present
            line = line.split('#')[0].strip()
            if not line:  # Skip if line was only a comment
                continue
                
            # Split by tabs and convert module.test_file to module/test_file.py
            try:
                # module_file, class_name, test_method = line.split('\t')
                module_file, class_name, test_method = line.split(None)
                module_parts = module_file.split('.')
                file_path = f"{'/'.join(module_parts)}.py"
                
                if file_path not in config:
                    config[file_path] = {}
                if class_name not in config[file_path]:
                    config[file_path][class_name] = []
                config[file_path][class_name].append(test_method)
            except ValueError as e:
                print(f"Warning: Skipping malformed line: {line}", file=sys.stderr)
                print()
                print("NOTE: you might want to use spaces2tabs.bash to fix this")
                print()
                raise
            
        return config
    
    def _parse_indent_format(self, file) -> Dict:
        """Parse indent-based format."""
        config = {}
        current_file = None
        current_class = None
        
        for line in file:
            line = line.rstrip()
            if not line:
                continue
                
            if not line.startswith(' '):
                # This is a file path
                current_file = line
                config[current_file] = {}
            elif line.startswith('    '):
                # This is a test method
                if current_class:
                    config[current_file][current_class].append(line.strip())
            else:
                # This is a test class
                current_class = line.strip()
                config[current_file][current_class] = []
                
        return config

    def generate_test_commands(self) -> List[str]:
        """Generate the test commands for all tests in the configuration."""
        commands = []
        
        for file_path, class_dict in self.config.items():
            for class_name, test_methods in class_dict.items():
                for test_method in test_methods:
                    cmd = f"python {file_path} {class_name}.{test_method}"
                    commands.append(cmd)
                    
        return commands

    
    def run_tests(self, repeat: Optional[int] = None) -> None:
        """Run all tests in the configuration."""
        commands = self.generate_test_commands()
        results = {}  # Store test results
        
        for cmd in commands:
            # Convert command back to tab format for result tracking
            module_path = cmd.split()[1].replace('/', '.').replace('.py', '')
            class_name = cmd.split()[2].split('.')[0]
            test_name = cmd.split()[2].split('.')[1]
            test_id = f"{module_path}\t{class_name}\t{test_name}"
            
            test_passed = True
            test_skipped = False
            
            for iteration in range(repeat or 1):
                print(f"\n{'='*80}\nRunning: {cmd} (Iteration {iteration + 1}/{repeat or 1})\n{'='*80}")
                try:
                    process = subprocess.Popen(
                        cmd.split(),
                        stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT,
                        text=True,
                        bufsize=1,
                        universal_newlines=True
                    )
                    
                    # Collect all output to check for "skipped"
                    output_lines = []
                    while True:
                        output = process.stdout.readline()
                        if output == '' and process.poll() is not None:
                            break
                        if output:
                            output_line = output.rstrip()
                            print(output_line)
                            output_lines.append(output_line.lower())
                            
                    return_code = process.poll()
                    if return_code != 0:
                        test_passed = False
                    if any('skipped' in line for line in output_lines):
                        test_skipped = True
                        
                except subprocess.CalledProcessError as e:
                    print(f"Error running test: {e}", file=sys.stderr)
                    print("Exit code:", e.returncode, file=sys.stderr)
                    test_passed = False
            
            # Store the final result
            if test_skipped:
                results[test_id] = "SKIP"
            else:
                results[test_id] = "OK" if test_passed else "FAIL"
        
        # Print summary at the end
        print("\n\nTest Summary:")
        print("="*80)
        for test_id, result in results.items():
            print(f"{test_id} # {result}")


    def generate_markdown(self, include_issues: bool = False) -> str:
        md_output = []
        
        for file_path, class_dict in self.config.items():
            for class_name, test_methods in class_dict.items():
                for test_method in test_methods:
                    # Convert filepath back to dot notation
                    module_path = file_path.replace('/', '.').replace('.py', '')
                    # Create the tab-separated test identifier
                    test_id = f"{module_path}\t{class_name}\t{test_method}"
                    
                    if include_issues:
                        issue_url = f"https://github.com/pytorch/pytorch/issues?q=is%3Aissue+is%3Aopen+{test_method}"
                        md_output.append(f"`{test_id}` [link]({issue_url})")
                    else:
                        md_output.append(f"`{test_id}`")
                    
                    md_output.append("")  # Add empty line between entries
        
        return "\n".join(md_output)


def main():
    parser = argparse.ArgumentParser(description='PyTorch test runner')
    parser.add_argument('config_file', help='Path to the test configuration file')
    parser.add_argument('--run', action='store_true', help='Run the tests')
    parser.add_argument('--print', action='store_true', help='Print markdown documentation')
    parser.add_argument('--repeat', type=int, help='Number of times to repeat each test')
    parser.add_argument('--format', choices=['auto', 'yaml', 'indent', 'table'], 
                       default='auto', help='Input file format')
    parser.add_argument('--find-issues', action='store_true', 
                       help='Include GitHub issue search links in markdown output')
    
    args = parser.parse_args()
    
    runner = TestRunner(args.config_file, format_type=args.format)
    
    if args.run:
        runner.run_tests(args.repeat)
    
    if args.print:
        print(runner.generate_markdown(include_issues=args.find_issues))

    if not (args.run or args.print):
        parser.print_help()

if __name__ == '__main__':
    main()