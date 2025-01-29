#/bin/bash
## uses rocpd to create some csv tabulated info
echo
echo "running runTracer.sh"
echo
runTracer.sh python $1
echo
echo "creating csv file"
echo
DB_PATH="trace.rpd"
OUTPUT_PATH="out.csv"
sqlite3 $DB_PATH ".mode csv" ".header on" ".output $OUTPUT_PATH" "select * from top;" ".output stdout"
