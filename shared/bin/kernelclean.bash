#!/bin/bash
## cleans up inductor output'ed triton templates (output_code.py)
if [ $# -ne 2 ]; then
   echo "Needs to args, for example:  arg1: output_code.py, arg2: out.py"
   exit 1
fi
## make bare @triton.jit functions
kernelextract.py $1 $2
## .. in kernelextract.py you have more tips on how to clean up the code
autoflake --remove-duplicate-keys --remove-all-unused-imports -i $2
ruff check --select F811 --fix $2
pyflakes $2
