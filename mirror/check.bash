#!/bin/bash
docker exec $container_name /root/shared/bin/container-health-check.py
if [ $? -ne 0 ]; then
    echo "❌ Container health check failed! Container may have hanging commands."
    echo "Terminating script to prevent wasting time with problematic container."
    exit 1
fi
docker exec $container_name python3 -c "
import sys
print('Python version:')
print(sys.version)
print('\nPython path:')
print(sys.path)
print()
import torch
import inspect
print(f'Torch is imported from: {inspect.getfile(torch)}')
print(f'Torch version: {torch.__version__}')
print('cuda avail:',torch.cuda.is_available())
torch.cuda.init()
print('cuda is initd:',torch.cuda.is_initialized())
print('cuda device count:',torch.cuda.device_count())
"
