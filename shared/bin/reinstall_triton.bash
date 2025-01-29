#!/bin/bash
cd /tmp/triton/python
pip uninstall -y triton && pip uninstall -y pytorch-triton_rocm
pip install .
