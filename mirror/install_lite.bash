#!/bin/bash
##
## WARNING
## THE LITE VERSION: DOES NOT INSTALL ANY PYTHON PACKAGES THAT MIGHT CONFLICT
##
## use at SERVER
## same directories both at server and client:
# mkdir -p $HOME/shared && mkdir -p $HOME/shared/notebook && mkdir -p $HOME/shared/script && mkdir -p $HOME/shared/bin
## .. as should be done by prepare.bash
## so this script we should only run after the container is running, i.e. after start.bash
## install some stuff into the container
docker exec $container_name /bin/sh -c '
    apt-get update &&
    apt-get install -y emacs less colorized-logs silversearcher-ag tree psmisc
'
## prepare the container
#docker exec $container_name pip install jupyter
## prepare git at server and client
## TODO: remove hard-coded names
git config --global user.name "${gitname}"
git config --global user.email "${gitemail}"
## prepare git at the container
docker exec $container_name /bin/sh -c "
git config --global user.name '${gitname}' && 
git config --global user.email '${gitemail}'
"
## modify container exec path for (shell) sessions in the container:
docker exec $container_name /bin/sh -c "echo 'source /root/shared/bin/contenv.bash' >> /root/.bashrc"
docker exec $container_name /bin/sh -c "echo \"export CTXENV=/root/shared/env/$contextname\" >> ~/.bashrc"
## -> that scripts added /root/shared/bin/ into the exec search path
## let's not do this: user needs to enforce this with source
# docker exec $container_name /bin/sh -c "echo 'source /root/shared/bin/buildenv.bash' >> /root/.bashrc"
## -> set some env variables for the build environment
#docker exec $container_name /bin/sh -c 'apt-get install sqlite3 libsqlite3-dev libfmt-dev -y'
#docker exec $container_name /bin/sh -c '
#  git clone https://github.com/ROCm/rocmProfileData &&
#  cd rocmProfileData &&
#  make &&
#  make install &&
#  cd rocpd_python &&
#  python setup.py install
#'
## enable mouse scroll in tmux:
cat << EOF > $HOME/.tmux.conf
set -g mouse on
EOF
## source our custom env variables at shell startup:
# echo "source mirror/env.bash" >> .bashrc
## .. done by prepare.bash
