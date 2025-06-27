#!/usr/bin/env python3
"""
Process pytest JUnit XML output to create summary files and failure details.

You need to install:

::

    pip install pytest-xdist

Used to postprocess this command:

::

    pytest -ra -n 1 --junitxml=results.xml your-test.py

(if you want FAST, use -n 5 etc. values)

NEW:

::

    pytest -v -ra -n 1 --forked --junitxml=results.xml your-test.py

-> isolates all tests into forked processes (otherwise with -n 5, all grouped 5 processes would run in a single process)

Creates directory failed/ where you have individual test failures as per different files
Creates also files failed,passed,skipped.txt that have this kind of format:

::

    ...
    test.test_ops	TestMathBitsCUDA	test_conj_view_H_cuda_complex64
    test.test_ops	TestMathBitsCUDA	test_conj_view_fft_ifftshift_cuda_complex64
    test.test_ops	TestMathBitsCUDA	test_conj_view__refs_unsqueeze_cuda_complex64
    test.test_ops	TestMathBitsCUDA	test_conj_view_masked_logsumexp_cuda_complex64
    test.test_ops	TestMathBitsCUDA	test_conj_view__refs_isinf_cuda_complex64
    ...

You can then strip that "test." part away (TODO: strip already in this script) 
and you have a fileformat you can further process with "test_runner.py" that 
runs tests individually and captures their stderr and exit codes (works for hwfails also)

For a certain unit-test ticket create a directory and in there a bash script for running a selection
of unit test suites:

::

    #!/bin/bash
    save=$PWD
    wrkdir="/var/lib/jenkins/pytorch/test"

    suites="TestMathBitsCUDA TestCommonCUDA TestCompositeComplianceCUDA TestFakeTensorCUDA"

    export TEST_WITH_ROCM=1
    export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=0
    export NN=5

    cd $save && rm -f tests.txt passed.txt failed.txt skipped.txt
    cd $save && rm -rf failed

    for suite in $suites
    do
        comm="pytest -v -ra -n "$NN" --junitxml="$save"/results.xml test_ops.py::"$suite
        echo
        echo $comm
        echo
        cd $wrkdir && $comm
        cd $save && process_junit_xml.py results.xml
    done
    cd $PWD

CAVEATS:

If you have a hw failure and the python test process crashes, the actual
hwfail will not be written into the separate file in "fail/", instead it just
writes a generic error message: pytest doesn't know how to capture stderr.

That's the reason you need to rerun failing tests with "test_runner.py"
"""
import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

def process_junit_xml(xml_file):
    # Create output files and directories - using append mode ('a') instead of write ('w')
    # TODO: we would like to have here a list of hwfails as well, i.e. tests that have hard-crashed (segfaults, memleaks, etc.)
    # for that, claude suggests we first run the test collector and then compare the results against that (hard-crashes don't produce any results)
    # but we'd actually would like to get the hwfail stderr message partitioned logfiles - seems to be impossible with pytest at the moment
    # for that we need to use "test_runner.py" from this directory
    # so we could use claude's suggestion to at least create a list of the hwfailed tests and then rerun that list with test_runner.py
    with open("tests.txt", "a") as tests_file, \
         open("passed.txt", "a") as passed_file, \
         open("failed.txt", "a") as failed_file, \
         open("skipped.txt", "a") as skipped_file:
        
        # Create the failed directory if it doesn't exist (but don't clear it)
        os.makedirs("failed", exist_ok=True)
        
        # Parse the XML file
        tree = ET.parse(xml_file)
        root = tree.getroot()
        
        # Process each test case
        for testcase in root.findall('.//testcase'):
            classname = testcase.get('classname')
            name = testcase.get('name')
            
            # Determine test status
            failure = testcase.find('failure')
            error = testcase.find('error')
            skipped = testcase.find('skipped')
            
            status = "PASSED"
            if failure is not None:
                status = "FAILED"
            elif error is not None:
                status = "ERROR"
            elif skipped is not None:
                reason = skipped.get('message', '')
                if 'xfail' in reason.lower():
                    status = "XFAILED"
                else:
                    status = "SKIPPED"
            
            # Skip XFAILED tests completely
            if status == "XFAILED":
                continue
            
            # Parse the classname to get directory, file, and class parts
            directory = ""
            file_part = ""
            class_part = ""
            
            if '::' in classname:
                # Handle pytest format (file::class)
                file_class_parts = classname.split('::')
                file_part = file_class_parts[0]
                class_part = file_class_parts[1] if len(file_class_parts) > 1 else ""
                
                # Extract directory if present
                if '/' in file_part:
                    directory = os.path.dirname(file_part)
                    file_part = os.path.basename(file_part)
            else:
                # Handle unittest format (directory.file.class)
                parts = classname.split('.')
                class_part = parts[-1]
                file_part = parts[-2] if len(parts) > 1 else ""
                directory = '.'.join(parts[:-2]) if len(parts) > 2 else ""
            
            # Format the test ID in the required format
            if directory:
                formatted_id = f"{directory}.{file_part}\t{class_part}\t{name}"
                directory_dot_file = f"{directory}.{file_part}"
            else:
                formatted_id = f"{file_part}\t{class_part}\t{name}"
                directory_dot_file = file_part
            
            # Write to tests.txt with status
            tests_file.write(f"{formatted_id}\n")
            
            # Write to passed.txt
            if status == "PASSED":
                passed_file.write(f"{formatted_id}\n")
            
            # Write to failed.txt (only FAILED and ERROR)
            if status in ["FAILED", "ERROR"]:
                failed_file.write(f"{formatted_id}\n")
                
                # Create detailed failure file
                output_filename = f"{directory_dot_file}.{class_part}.{name}.out"
                output_filename = output_filename.replace('/', '.')
                
                # Write failure details to the file
                with open(os.path.join("failed", output_filename), "w") as failure_file:
                    failure_file.write(f"Test: {directory_dot_file}::{class_part}::{name}\n")
                    failure_file.write(f"Status: {status}\n\n")
                    
                    if failure is not None:
                        failure_file.write("Failure Details:\n")
                        failure_file.write(failure.get('message', '') + "\n")
                        failure_file.write(failure.text or '')
                    
                    if error is not None:
                        failure_file.write("Error Details:\n")
                        failure_file.write(error.get('message', '') + "\n")
                        failure_file.write(error.text or '')
            
            # Write to skipped.txt (only SKIPPED, not XFAILED)
            if status == "SKIPPED":
                skipped_file.write(f"{formatted_id}\n")

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} junit_xml_file")
        sys.exit(1)
    
    xml_file = sys.argv[1]
    if not os.path.exists(xml_file):
        print(f"Error: File '{xml_file}' not found")
        sys.exit(1)
    
    process_junit_xml(xml_file)
    print(f"Processing complete. Output files appended: tests.txt, passed.txt, failed.txt, skipped.txt")

if __name__ == "__main__":
    main()
