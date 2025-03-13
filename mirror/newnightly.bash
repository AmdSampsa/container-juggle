#!/bin/bash
## usage:
## newnightly.bash name hostnick

if [ ! -f ~/mirror/context/my_nightly_scaffold.bash ]; then
    echo "Error: Source file ~/mirror/context/my_nightly_scaffold.bash does not exist"
    echo "Please copy ctx_scaffold.bash into my_nightly_scaffold.bash and put therein your individual data - then run this again"
    exit 1
fi


# The YAML file
CONFIG_FILE=$HOME/mirror/context/hosts.yaml

# The host name you want to get the address for
HOST_NAME=$2

# Use Python to extract the host address
HOST_ADDRESS=$(python3 -c "
import yaml
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(config['hosts']['$HOST_NAME']['host'])
")

# Remove quotes if present
# HOST_ADDRESS=${HOST_ADDRESS//\"/}

DATESTAMP=$(date +"%d%m%y")
contextname=$1"-nightly-"$DATESTAMP
container_name=$USER"-nightly-"$DATESTAMP
cp ~/mirror/context/my_nightly_scaffold.bash ~/mirror/context/$contextname.bash
chmod a+x ~/mirror/context/$contextname.bash
sed -i "s/export contextname=/export contextname=$contextname/" ~/mirror/context/$contextname.bash
sed -i "s/export container_name=/export container_name=$container_name/" ~/mirror/context/$contextname.bash
sed -i "s/export hostname=/export hostname=$HOST_ADDRESS/" ~/mirror/context/$contextname.bash
sed -i "s/export hostnick=/export hostnick=$HOST_NAME/" ~/mirror/context/$contextname.bash

echo 
echo wrote $contextname.bash
echo
