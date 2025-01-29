#!/bin/bash
## dl first and last lines of a HUGE log from an URL
wget -q -O - $1 | head -n 10000 > log.txt
echo "###### CUT #######" >> log.txt
echo "###### CUT #######" >> log.txt
echo "###### CUT #######" >> log.txt
wget -q -O - $1 | tail -n 10000 >> log.txt
