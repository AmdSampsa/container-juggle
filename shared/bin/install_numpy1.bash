#!/bin/bash
echo "installing numpy 1 and friends"
pip uninstall -y matplotlib pandas
pip install numpy==1.22.4
python -c "import numpy; print(f'numpy=={numpy.__version__}')" > /tmp/cc_.txt
pip install -c /tmp/cc_.txt matplotlib
pip install -c /tmp/cc_.txt pandas
