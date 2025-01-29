#!/bin/bash
echo "Configuring git"
docker exec $container_name /bin/sh -c "
git config --global user.name '${gitname}' && 
git config --global user.email '${gitemail}'
"
echo "Setting ssh keys"
docker exec $container_name mkdir -p /root/.ssh
# copy ssh keys to container
cp -r .ssh ssh_temp
chmod -R u+r+w+x ssh_temp
docker cp ssh_temp/. $container_name:/root/.ssh/
# Set correct permissions inside container
docker exec $container_name chmod 700 /root/.ssh
docker exec $container_name chmod 600 /root/.ssh/id_rsa
docker exec $container_name chmod 644 /root/.ssh/id_rsa.pub
# remove tempdir
shred -u -n 3 ssh_temp/*
rm -rf ssh_temp
