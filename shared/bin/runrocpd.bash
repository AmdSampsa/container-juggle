#/bin/bash
## uses rocpd to create a trace json file
##
echo
echo "running runTracer.sh"
echo
runTracer.sh python $1
echo
echo "creating json file"
echo
python $ROCPROFDIR/tools/rpd2tracing.py trace.rpd trace_rocpd.json
