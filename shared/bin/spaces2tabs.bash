#!/bin/bash
echo
echo "converting continuous spaces regions to tabs"
echo
sed -i 's/[[:space:]]\{1,\}/\t/g' $1
