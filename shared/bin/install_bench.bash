#!/bin/bash
cd /root
git clone --depth 1 https://github.com/pytorch/benchmark
cd benchmark

# Fix ROCm/CUDA version constraints issue (upstream PR pending since May 2024)
# here are some
# https://github.com/pytorch/benchmark/pull/2626
# https://github.com/pytorch/benchmark/pull/2614

# Strip local version identifiers (e.g., +rocm7.1.1) from constraints to fix pip resolution
echo
echo "WARNING: Patching utils/__init__.py for ROCm/CUDA builds..."
echo
sed -i 's/fp.write(f"{k}=={v}\\n")/fp.write(f"{k}=={v.split(\"+\")[0] if \"+\" in v else v}\\n")/' utils/__init__.py

# suppose your failing test you want to take a closer look is basic_gnn_gcn
python3 install.py dpn107 # just install the required test
pip install -e . # install torchbench as a library
