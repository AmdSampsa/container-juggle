#!/usr/bin/env python3

import sys

def convert_to_pytest_format(input_file, output_file):
    with open(input_file, 'r') as f_in:
        with open(output_file, 'w') as f_out:
            for line in f_in:
                parts = line.strip().split('\t')
                if len(parts) >= 3:
                    # Assuming format: module, suite, test
                    module = parts[0]
                    if module.startswith("test."):
                        # Strip "test." prefix if present
                        module = module[5:]
                    
                    suite = parts[1]
                    test = parts[2]
                    
                    # Write in pytest format: test_ops.py::TestSuiteName::test_name
                    f_out.write(f"test_ops.py::{suite}::{test}\n")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input_file output_file")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    convert_to_pytest_format(input_file, output_file)
    print(f"Converted {input_file} to pytest format in {output_file}")
