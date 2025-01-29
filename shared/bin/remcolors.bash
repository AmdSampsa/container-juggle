#!/bin/bash
sed -i 's/\x1b\[[0-9;]*m//g' $1
