#!/bin/bash
## use at CLIENT
## kill any remnant jupyter notebooks running inside the container:
ssh -p $sshport $username@$hostname -p$sshport "docker exec $container_name pkill -f jupyter"
# local-port:localhost:remote-port
#ssh -L 8888:localhost:9999 $username@$hostname -p$sshport \
#  "docker exec $container_name bash -ic 'pkill -f jupyter && jupyter notebook --ip 0.0.0.0 --port 9999 --no-browser --allow-root --NotebookApp.token=\"\" --NotebookApp.password=\"\" --notebook-dir=/root/shared/notebook'"
# that doesn't propagate the .bashrc env variables dont propagate to jupyter notebook
# jupyter uses sh as its internal shell:
#ssh -L 8888:localhost:9999 $username@$hostname -p$sshport \
#  "docker exec $container_name sh -c '. /root/shared/bin/sh_env.sh && env && jupyter notebook --ip 0.0.0.0 --port 9999 --no-browser --allow-root --NotebookApp.token=\"\" --NotebookApp.password=\"\" --notebook-dir=/root/shared/notebook'"
#

# Generate auth port forwards
# used for github auth
AUTH_PORTS=""
# for port in {55000..58000}; do
for port in {55000..55002}; do
    AUTH_PORTS="$AUTH_PORTS -L $port:localhost:$port"
done

ssh -p $sshport \
  $AUTH_PORTS \
  -L 8888:localhost:9999 \
  $username@$hostname -p$sshport \
  "docker exec $container_name sh -c '. /root/shared/bin/sh_env.sh && env && jupyter lab --ip 0.0.0.0 --port 9999 --no-browser --allow-root --NotebookApp.token=\"\" --NotebookApp.password=\"\" --notebook-dir=/root/shared/notebook'"

ssh -p $sshport $username@$hostname -p$sshport "docker exec $container_name pkill -f jupyter"
