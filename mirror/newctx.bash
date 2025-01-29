#!/bin/bash
if [ ! -f ~/mirror/context/my_scaffold.bash ]; then
    echo "Error: Source file ~/mirror/context/my_scaffold.bash does not exist"
    echo "Please copy ctx_scaffold.bash into my_scaffold.bash and put therein your individual data - then run this again"
    exit 1
fi
cp ~/mirror/context/my_scaffold.bash ~/mirror/context/$1.bash
chmod a+x ~/mirror/context/$1.bash
sed -i "s/export contextname=/export contextname=$1/" ~/mirror/context/$1.bash
