#!/bin/bash
if ! docker ps -q -f name=$container_name > /dev/null; then
    echo "Container $container_name not found"
    exit 1
fi
docker exec $container_name /bin/sh -c "
    PYTORCH_TEST_WITH_ROCM=1 pytest -v pytorch/test/$1 &> /root/sharedump/test_out.txt
" || echo "Test execution failed"

