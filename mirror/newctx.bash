#!/bin/bash
if [ ! -f ~/mirror/context/my_scaffold.bash ]; then
    echo "Error: Source file ~/mirror/context/my_scaffold.bash does not exist"
    echo "Please copy ctx_scaffold.bash into my_scaffold.bash and put therein your individual data - then run this again"
    exit 1
fi
cp ~/mirror/context/my_scaffold.bash ~/mirror/context/$1.bash
chmod a+x ~/mirror/context/$1.bash
sed -i "s/export contextname=/export contextname=$1/" ~/mirror/context/$1.bash

echo "Context file created: ~/mirror/context/$1.bash"
echo ""
echo "Next steps will:"
echo "  1. Create directory: ~/shared/tests/$1"
echo "  2. Create file: ~/shared/tests/$1/README.md"
echo "  3. Update PRINCIPAL_DIR in ~/mirror/context/$1.bash"
echo ""
read -p "Proceed? [y/N] " answer
if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo "Aborted. Context file created but directory not set up."
    exit 0
fi

mkdir -p  ~/shared/tests/$1
touch  ~/shared/tests/$1/README.md
sed -i "s|export PRINCIPAL_DIR=.*|export PRINCIPAL_DIR=\"/root/shared/tests/$1\"|" ~/mirror/context/$1.bash
echo "Done! Context '$1' is ready."
