#/bin/bash
cd /root
git clone --depth 1 https://github.com/pytorch/benchmark
cd benchmark
# suppose your failing test you want to take a closer look is basic_gnn_gcn
python3 install.py dpn107 # just install the required test
pip install -e . # install torchbench as a library
