#!/bin/bash
cat $1 | grep FAILED | sed 's/.*:://' | sed 's/ FAILED.*//'
