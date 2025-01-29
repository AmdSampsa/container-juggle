#!/usr/bin/python
"""Finds all expected inline fixtures with tl.load instructions
"""
import glob
import os

def process_file(filename):
    inside_assert = False
    with open(filename, 'r') as f:
        for line_num, line in enumerate(f, 1):
            if 'self.assertExpectedInline(' in line:
                inside_assert = True
            elif inside_assert:
                if 'tl.load' in line:
                    print(f"{filename}:{line_num}: {line.strip()}")
                if line.strip().endswith(')'):
                    inside_assert = False

if __name__ == "__main__":
    for filename in glob.glob("*.py"):
        if os.path.isfile(filename):
            process_file(filename)

