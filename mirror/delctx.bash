#!/bin/bash
if [ ! -f ~/mirror/context/$1.bash ]; then
    echo "cant find context "$1
    exit 1
fi
mkdir -p ~/mirror/context/removed
source ~/mirror/context/$1.bash
ssh -t -p"$sshport" "$username@$hostname" "
docker container stop $container_name;
docker container rm $container_name;
rm ~/mirror/context/$1.bash;
tmux kill-server;
"
# maybe not do that here:
# docker image prune -a -f
mv ~/mirror/context/$1.bash ~/mirror/context/removed/$1.bash
# try to remove th workspace file .. if it exists
# rm -f $HOME/wrkspaces/$1-container.code-workspace
rm -f ~/wrkspaces/$1.code-workspace
