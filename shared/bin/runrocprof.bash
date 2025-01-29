#!/bin/bash
## runs rocprof v1 - maybe don't use this but rocprof v3 instead
#mkdir -p rocprof_out
#cd rocprof_out
echo pmc: > in.txt
rocprof -i in.txt --hip-trace --roctx-trace --timestamp on -d rocout python $1 && \
python $ROCPROFDIR/shelve/rocprof2rpd.py --ops_input_file hcc_ops_trace.txt --api_input_file hip_api_trace.txt --roctx_input_file roctx_trace.txt out.rpd && \
python $ROCPROFDIR/tools/rpd2tracing.py out.rpd trace_rocprof.json
#cd ..
