#!/bin/bash
## use at SERVER
## same directories both at server and client:
# mkdir -p $HOME/shared && mkdir -p $HOME/shared/notebook && mkdir -p $HOME/shared/script && mkdir -p $HOME/shared/bin
## .. as should be done by prepare.bash
## so this script we should only run after the container is running, i.e. after start.bash
## install some stuff into the container
echo "Installing emacs, less, etc. into container"
docker exec $container_name /bin/sh -c '
    apt-get update &&
    apt-get install -y emacs less colorized-logs silversearcher-ag tree dialog psmisc ccache ssh iputils-ping
'
echo "Installing github tools"
docker exec $container_name /bin/sh -c '
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg &&
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null &&
  apt update &&
  apt install gh
'
echo "Installing some python packages"
docker exec $container_name pip install jupyter tabulate ruff pyflakes autoflake pytest-xdist
## prepare git at server and client
## NOTE: this was done already in prepare.bash for the host:
#git config --global user.name "${gitname}"
#git config --global user.email "${gitemail}"
## prepare git at the container
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
echo "setting env"
## modify container exec path for (shell) sessions in the container:
docker exec $container_name /bin/sh -c "echo \"export contextname=$contextname\" >> /root/.bashrc"
docker exec $container_name /bin/sh -c "echo \"export gituser=$gituser\" >> ~/.bashrc"
docker exec $container_name /bin/sh -c "echo 'source /root/shared/bin/contenv.bash' >> /root/.bashrc"
# docker exec $container_name /bin/sh -c "echo \"export CTXENV=/root/shared/env/$contextname\" >> ~/.bashrc" # -> NOPES: we do this now when logging with ssh and in contenv.bash
## -> that scripts added /root/shared/bin/ into the exec search path
## copy gdb config file in-place:
docker exec $container_name /bin/sh -c "mkdir -p /root/.vscode/"
docker cp ~/shared/launch.json $container_name:/root/.vscode/launch.json
## let's not do this: user needs to enforce this with source
# docker exec $container_name /bin/sh -c "echo 'source /root/shared/bin/buildenv.bash' >> /root/.bashrc"
## -> set some env variables for the build environment
docker exec $container_name /bin/sh -c 'apt-get install sqlite3 libsqlite3-dev libfmt-dev -y'

# Function to detect GPU vendor
detect_gpu_vendor() {
    # Check for AMD GPUs using rocminfo
    if command -v rocminfo &> /dev/null && rocminfo &> /dev/null; then
        echo "amd"
        return
    fi
    # Check for NVIDIA GPUs using nvidia-smi
    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
        echo "nvidia"
        return
    fi
    echo "none"
}

# Detect GPU vendor
GPU_VENDOR=$(detect_gpu_vendor)
echo "Detected GPU vendor: $GPU_VENDOR"

if [ "$GPU_VENDOR" = "amd" ]; then
  echo "Installing ROCm profiling tools..."
  ## the main branch might have bugs & this might crash..
  docker exec $container_name /bin/sh -c '
    git clone https://github.com/ROCm/rocmProfileData &&
    cd rocmProfileData &&
    make &&
    make install &&
    cd rocpd_python &&
    python setup.py install
  '
fi

## enable mouse scroll in tmux:
cat << EOF > $HOME/.tmux.conf
set -g mouse on
EOF
## source our custom env variables at shell startup:
# echo "source mirror/env.bash" >> .bashrc
## .. done by prepare.bash
echo
echo "DONE!"
echo
