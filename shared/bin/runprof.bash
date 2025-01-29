#/bin/bash
echo
echo "running runTracer.sh"
echo
runTracer.sh python $1
echo
echo "creating json file"
echo
python $ROCPROFDIR/rpd2tracing.py trace.rpd trace.json
