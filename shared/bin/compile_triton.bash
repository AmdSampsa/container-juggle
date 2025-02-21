#!/bin/bash
cd $HOME/triton$1/python
pip uninstall -y triton && pip uninstall -y pytorch-triton-rocm && rm -rf ~/.triton
pip install .
