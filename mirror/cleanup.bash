#!/bin/bash
# Just list them first
echo
echo Will delete these directories / files:
echo
find . -type d \( -name "torch_compile_debug" -o -name ".ipynb_checkpoints" -o -name "res_cache" \) -print
echo
echo "Press any key to delete.."
read -n1
echo
# Then delete when you're ready
find . -type d \( -name "torch_compile_debug" -o -name ".ipynb_checkpoints" -o -name "res_cache" \) -exec rm -rf {} +
echo
echo All done!

