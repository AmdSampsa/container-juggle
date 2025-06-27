#!/usr/bin/env python3
"""
Pytest Log Parser - Parses large pytest logs and reports test status

This script processes pytest log files line by line to identify test results without 
loading the entire file into memory. It detects test status (PASSED, FAILED, etc.),
identifies hardware failures, inductor failures, and unresolved tests, and saves test output to separate files.

You might want to use this with the logfiles provided by the QA team in the jira tickets.

When running tests with pytest yourself and analyzing that output, please use the script

process_junit_xml.py 

instead (and read the comments in that script)
"""
import argparse
import re
import sys
import os
from pathlib import Path


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Parse pytest logs and report test status")
    parser.add_argument("log_file", help="Path to the pytest log file")
    parser.add_argument("--report-skipped", action="store_true", 
                        help="Report SKIPPED tests (default: don't report)")
    parser.add_argument("--report-passed", action="store_true",
                        help="Report PASSED tests (default: don't report)")
    parser.add_argument("--hw-keywords", type=str, default=None,
                        help="Comma-separated list of hardware failure keywords")
    parser.add_argument("--inductor-keywords", type=str, default=None,
                        help="Comma-separated list of inductor failure keywords")
    parser.add_argument("--hw-fails-dir", type=str, default="hw_fails",
                        help="Directory to save hardware failure output files")
    parser.add_argument("--inductor-fails-dir", type=str, default="inductor_fails",
                        help="Directory to save inductor failure output files")
    parser.add_argument("--save-outputs", action="store_true",
                        help="Save test outputs to separate files")
    return parser.parse_args()


class TestStatus:
    """Possible states for a test."""
    PASSED = "PASSED"
    FAILED = "FAILED"
    XFAIL = "XFAIL"
    SKIPPED = "SKIPPED"
    HWFAIL = "HWFAILED"
    INDUCTOR = "INDUCTOR_FAILED"
    WARNING = "WARNING"
    INDUCTOR_WARNING = "INDUCTOR_WARNING"
    UNRESOLVED = "UNRESOLVED"


class PytestLogParser:
    def __init__(self, hw_keywords=None, inductor_keywords=None, report_skipped=False, 
                 report_passed=False, save_outputs=False, hw_fails_dir="hw_fails", 
                 inductor_fails_dir="inductor_fails"):
        """Initialize the parser with configuration.
        
        Args:
            hw_keywords: List of strings indicating hardware failure
            inductor_keywords: List of strings indicating inductor failure
            report_skipped: Whether to report skipped tests
            report_passed: Whether to report passed tests
            save_outputs: Whether to save test outputs to separate files
            hw_fails_dir: Directory to save hardware failure output files
            inductor_fails_dir: Directory to save inductor failure output files
        """
        self.current_test = None
        self.hw_keywords = hw_keywords or ["core dump", "hardware exception", "segmentation fault"]
        self.inductor_keywords = inductor_keywords or ["triton compilation"] # WARNING: do not use just a single word # WARNING: CHECK PARSEARGS DEFAULTS
        self.report_skipped = report_skipped
        self.report_passed = report_passed
        self.save_outputs = save_outputs
        self.hw_fails_dir = hw_fails_dir
        self.inductor_fails_dir = inductor_fails_dir
        self.reported_tests = set()  # Keep track of tests that have been reported
        
        # Create output directories if they don't exist
        if self.save_outputs:
            os.makedirs(self.hw_fails_dir, exist_ok=True)
            os.makedirs(self.inductor_fails_dir, exist_ok=True)
            os.makedirs("failures", exist_ok=True)
        
        # Current buffer for test output
        self.current_output = []
        
        # Compiled regex for better performance
        # self.test_pattern = re.compile(r'^([a-zA-Z0-9_]+\.py)::([^:]+)::([^:\s]+)')
        self.test_pattern = re.compile(r'^((?:[\w/]+/)?[\w]+\.py)::([^:]+)::([^:\s]+)')
        self.status_pattern = re.compile(r'(PASSED|FAILED|XFAIL|SKIPPED)(\s+\[\d+\.\d+s\])?')
        
    def process_log(self, log_file):
        """Process the pytest log file line by line.
        
        Args:
            log_file: Path to the pytest log file
        """
        try:
            with open(log_file, 'r', errors='replace') as f:
                for line in f:
                    self._process_line(line.strip())
                
                # Handle the case where the log ends with an unresolved test
                if self.current_test and not hasattr(self.current_test, 'status'):
                    self._report_test(TestStatus.UNRESOLVED)
        except FileNotFoundError:
            print(f"Error: Log file '{log_file}' not found")
            sys.exit(1)
        except IOError as e:
            print(f"Error reading log file: {e}")
            sys.exit(1)
    
    def _process_line(self, line):
        """Process a single line from the log file.
        
        Args:
            line: A single line from the pytest log
        """
        # Check if this line contains a test identifier
        test_match = self.test_pattern.search(line)
        if test_match:
            module = test_match.group(1)
            test_class = test_match.group(2)
            test_name = test_match.group(3)
            
            # Check if this is the same test as the current one
            if (self.current_test and 
                self.current_test.module == module and
                self.current_test.test_class == test_class and
                self.current_test.test_name == test_name):
                # Same test - continue collecting output
                self.current_output.append(line)
                
                # Check for status in this line - treat it as an update
                # This handles rerun tests by using the latest status
                status_match = self.status_pattern.search(line)
                if status_match:
                    status = status_match.group(1)
                    # Process all collected output to determine the actual status
                    final_status = self._determine_test_status(status)
                    
                    # If we already have a status for this test, update it
                    if hasattr(self.current_test, 'status'):
                        # Remove from reported tests if it was reported
                        test_id = self._get_test_id()
                        if test_id in self.reported_tests:
                            self.reported_tests.remove(test_id)
                        # Update the status
                        self.current_test.status = final_status
                        # Report with the new status (unless it's PASSED and we don't report those)
                        if not (final_status == TestStatus.PASSED and not self.report_passed) and \
                           not (final_status == TestStatus.SKIPPED and not self.report_skipped) and \
                           not (final_status == TestStatus.XFAIL and not self.report_skipped):
                            self._report_test(final_status)
                    else:
                        # First status for this test
                        self._report_test(final_status)
            else:
                # New test
                # If we have an unresolved test, report it before moving on
                if self.current_test and not hasattr(self.current_test, 'status'):
                    # Process all collected output to determine the actual status
                    final_status = self._determine_test_status(TestStatus.UNRESOLVED)
                    self._report_test(final_status)
                
                # Start tracking a new test
                self.current_test = TestInfo(
                    module=module,
                    test_class=test_class,
                    test_name=test_name
                )
                
                # Reset the output buffer for the new test
                self.current_output = [line]
                
                # Check if the status is on the same line
                status_match = self.status_pattern.search(line)
                if status_match:
                    status = status_match.group(1)
                    # Process all collected output to determine the actual status
                    final_status = self._determine_test_status(status)
                    self._report_test(final_status)
                    return
        
        # If we're not tracking a test, skip processing
        if not self.current_test:
            return
            
        # Add this line to the current output
        if not hasattr(self.current_test, 'status'):
            self.current_output.append(line)
        
        # If the test is already resolved, skip additional processing
        if hasattr(self.current_test, 'status'):
            return
        
        # Check for test status indicators
        status_match = self.status_pattern.search(line)
        if status_match:
            status = status_match.group(1)
            # Process all collected output to determine the actual status
            final_status = self._determine_test_status(status)
            self._report_test(final_status)
            
    def _determine_test_status(self, initial_status):
        """Determine the final test status based on the collected output.
        
        Args:
            initial_status: The initial test status from pytest output
            
        Returns:
            The final test status after analyzing the output
        """
        # Concatenate all output for easier searching
        output_text = "\n".join(self.current_output).lower()
        
        # Handle different cases based on initial status
        if initial_status == TestStatus.PASSED:
            # Check if this is a test that PASSED but had inductor warnings
            #for keyword in self.inductor_keywords:
            #    # print(">",keyword.lower())
            if any(keyword.lower() in output_text for keyword in self.inductor_keywords):
                # print("FUCK")
                return TestStatus.INDUCTOR_WARNING
            # Check if this is a test that PASSED but had hardware warnings
            elif any(keyword.lower() in output_text for keyword in self.hw_keywords):
                return TestStatus.WARNING
            # Regular PASS
            return TestStatus.PASSED
            
        elif initial_status == TestStatus.FAILED:
            # Check for hardware failures in failed tests
            if any(keyword.lower() in output_text for keyword in self.hw_keywords):
                return TestStatus.HWFAIL
            # Check for inductor failures in failed tests
            elif any(keyword.lower() in output_text for keyword in self.inductor_keywords):
                return TestStatus.INDUCTOR
            # Regular FAIL
            return TestStatus.FAILED
            
        elif initial_status == TestStatus.UNRESOLVED:
            # Check for hardware failures in unresolved tests
            if any(keyword.lower() in output_text for keyword in self.hw_keywords):
                return TestStatus.HWFAIL
            # Check for inductor failures in unresolved tests
            elif any(keyword.lower() in output_text for keyword in self.inductor_keywords):
                return TestStatus.INDUCTOR
            # Regular UNRESOLVED
            return TestStatus.UNRESOLVED
            
        # Return the initial status for all other cases
        return initial_status
    
    def _line_contains_hw_failure(self, line):
        """Check if a line contains hardware failure indicators.
        
        Args:
            line: A single line from the pytest log
            
        Returns:
            bool: True if the line contains a hardware failure indicator
        """
        line_lower = line.lower()
        return any(keyword.lower() in line_lower for keyword in self.hw_keywords)
        
    def _line_contains_inductor_failure(self, line):
        """Check if a line contains inductor failure indicators.
        
        Args:
            line: A single line from the pytest log
            
        Returns:
            bool: True if the line contains an inductor failure indicator
        """
        line_lower = line.lower()
        return any(keyword.lower() in line_lower for keyword in self.inductor_keywords)
    
    def _save_test_output(self, status):
        """Save the current test output to a file for hardware or inductor failures.
        
        Args:
            status: The test status (PASSED, FAILED, etc.)
        """
        if not self.save_outputs or not self.current_test or not self.current_output:
            return
            
        # Create a filename based on the test name
        filename = f"{self.current_test.test_name}.out"
        
        # Determine the appropriate directory based on status
        if status == TestStatus.HWFAIL or status == TestStatus.WARNING:
            output_dir = self.hw_fails_dir
        elif status == TestStatus.INDUCTOR or status == TestStatus.INDUCTOR_WARNING:
            # NOTE: INDUCTOR WARNING cases are written also
            output_dir = self.inductor_fails_dir
        elif status == TestStatus.FAILED:
            output_dir = "failures"
        else:
            return
            
        filepath = os.path.join(output_dir, filename)
        
        # Write the output to the file
        with open(filepath, 'w') as f:
            f.write('\n'.join(self.current_output))
    
    def _get_test_id(self):
        """Get the full test identifier."""
        return f"{self.current_test.module}::{self.current_test.test_class}::{self.current_test.test_name}"
    
    def _report_test(self, status):
        """Report the test status.
        
        Args:
            status: The test status (PASSED, FAILED, etc.)
        """
        # Skip if the test has already been reported
        test_id = self._get_test_id()
        if test_id in self.reported_tests:
            self.current_test.status = status
            return
            
        if status == TestStatus.SKIPPED and not self.report_skipped:
            # Don't report skipped tests unless configured to do so
            self.current_test.status = status
            return
            
        if status == TestStatus.PASSED and not self.report_passed:
            # Don't report passed tests unless configured to do so
            self.current_test.status = status
            return
        
        if status == TestStatus.XFAIL and not self.report_skipped:
            # Don't report XFAIL tests unless report_skipped is enabled
            self.current_test.status = status
            return
        
        print(f"{test_id} - {status}")
        
        # Save test output before marking as resolved (only for HWFAIL and INDUCTOR)
        self._save_test_output(status)
        
        # Mark the test as reported
        self.reported_tests.add(test_id)
        self.current_test.status = status


class TestInfo:
    """Information about a test."""
    def __init__(self, module, test_class, test_name):
        """Initialize test information.
        
        Args:
            module: The test module (e.g., test_ops.py)
            test_class: The test class (e.g., TestMathBitsCUDA)
            test_name: The test name (e.g., test_neg_conj_view_mean_cuda_complex128)
        """
        self.module = module
        self.test_class = test_class
        self.test_name = test_name


def main():
    """Main entry point for the script."""
    args = parse_args()
    
    # Parse failure keywords
    # hw_keywords = [kw.strip() for kw in args.hw_keywords.split(",")]
    # inductor_keywords = [kw.strip() for kw in args.inductor_keywords.split(",")]
    
    # Create and run the parser
    parser = PytestLogParser(
        hw_keywords=args.hw_keywords,
        inductor_keywords=args.inductor_keywords,
        report_skipped=args.report_skipped,
        report_passed=args.report_passed,
        save_outputs=args.save_outputs,
        hw_fails_dir=args.hw_fails_dir,
        inductor_fails_dir=args.inductor_fails_dir
    )
    parser.process_log(args.log_file)


if __name__ == "__main__":
    main()