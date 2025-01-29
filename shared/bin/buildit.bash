#!/bin/bash
dumpfile=/root/sharedump/compile.txt
echo take a look into $dumpfile
cd /var/lib/jenkins/pytorch
date > $dumpfile
echo "DEBUG="$DEBUG >> $dumpfile
echo "PYTORCH_ROCM_ARCH="$PYTORCH_ROCM_ARCH >> $dumpfile
echo "" >> $dumpfile
python setup.py develop >> $dumpfile 2>&1
echo "READY!"
echo "Don't forget to"
echo "python setup.py install"
