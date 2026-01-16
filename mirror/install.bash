#!/bin/bash
## use at SERVER
## same directories both at server and client:


#!/bin/bash

# Initialize flags with default values
LATEST=false # pull & compile latest pytorch
TOOLS=true # cli tools etc.
SAMPSA=false # my specific confs

userflag="-u 0" # this forces the container to use root
# userflag="" # no specific user.. WARNING: all the scripts assume you have access to /root

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --latest)
      LATEST=true
      shift
      ;;
    --no-tools)
      TOOLS=false
      shift
      ;;
    --sampsa)
      SAMPSA=true
      shift
      ;;
    *)
      # Unknown option
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# mkdir -p $HOME/shared && mkdir -p $HOME/shared/notebook && mkdir -p $HOME/shared/script && mkdir -p $HOME/shared/bin
## .. as should be done by prepare.bash
## so this script we should only run after the container is running, i.e. after start.bash
## install some stuff into the container

if [ "$TOOLS" = true ]; then
  echo "Installing emacs, less, etc. into container"
  docker exec $userflag $container_name /bin/sh -c '
      (apt-get update && 
      apt-get install -y emacs less colorized-logs silversearcher-ag tree dialog psmisc ccache ssh iputils-ping psmisc) || 
      (yum install -y emacs less the_silver_searcher tree dialog psmisc ccache openssh iputils psmisc)
  '
  docker exec $userflag $container_name /bin/sh -c '
    (apt-get install -y sqlite3 libsqlite3-dev libfmt-dev) || 
    (yum install -y sqlite sqlite-devel fmt-devel)
'
fi

#echo "Installing github tools"
#docker exec $userflag $container_name /bin/sh -c '
#  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg &&
#  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null &&
#  apt update &&
#  apt install gh
#'

docker exec $container_name /root/shared/bin/container-health-check.py
if [ $? -ne 0 ]; then
    echo "❌ Container health check failed! Container may have hanging commands."
    echo "Terminating script to prevent wasting time with problematic container."
    exit 1
fi

echo "Installing some python packages"
docker exec $userflag $container_name pip install jupyter tabulate ruff pyflakes autoflake pytest-xdist
## prepare git at server and client
## NOTE: this was done already in prepare.bash for the host:
#git config --global user.name "${gitname}"
#git config --global user.email "${gitemail}"
## prepare git at the container
# echo "Configuring git"
#docker exec $userflag $container_name /bin/sh -c "
#git config --global user.name '${gitname}' && 
#git config --global user.email '${gitemail}'
#"
echo "Copying git config files"
for file in $HOME/shared/secret/.*gitconfig*; do
  echo $file
  docker cp "$file" $container_name:/root/
done
#
echo "Setting ssh keys"
docker exec $userflag $container_name mkdir -p /root/.ssh
# copy ssh keys to container
cp -r .ssh ssh_temp
chmod -R u+r+w+x ssh_temp
docker cp ssh_temp/. $container_name:/root/.ssh/
# Set correct permissions inside container
docker exec $userflag $container_name chmod 700 /root/.ssh
docker exec $userflag $container_name chmod 600 /root/.ssh/id_rsa
docker exec $userflag $container_name chmod 644 /root/.ssh/id_rsa.pub
# remove tempdir
shred -u -n 3 ssh_temp/*
rm -rf ssh_temp
echo "setting env"
docker exec $userflag $container_name /bin/sh -c "
  # Remove from marker onwards, then add new content
  sed -i '/#CONTAINER-JUGGLE>/,\$d' /root/.bashrc
  echo '#CONTAINER-JUGGLE>' >> /root/.bashrc
  echo 'export contextname=$contextname' >> /root/.bashrc
  echo 'export PRINCIPAL_DIR=$PRINCIPAL_DIR' >> /root/.bashrc  
  echo 'source /root/shared/bin/contenv.bash' >> /root/.bashrc
  echo 'source /root/shared/secret/env.bash' >> /root/.bashrc
  echo 'set bell-style none' >> /root/.inputrc
"
# docker exec $userflag $container_name /bin/sh -c "echo \"export CTXENV=/root/shared/env/$contextname\" >> ~/.bashrc" # -> NOPES: we do this now when logging with ssh and in contenv.bash
## -> that scripts added /root/shared/bin/ into the exec search path
## copy gdb config file in-place:
docker exec $userflag $container_name /bin/sh -c "mkdir -p /root/.vscode/"
docker cp ~/shared/launch.json $container_name:/root/.vscode/launch.json
## let's not do this: user needs to enforce this with source
# docker exec $userflag $container_name /bin/sh -c "echo 'source /root/shared/bin/buildenv.bash' >> /root/.bashrc"
## -> set some env variables for the build environment

## stupid debugpy only accepts /bin/python as the python interpreter so let's fix that:
# One-liner to replace both symlinks:
#echo "substituting python symlinks"
#echo
#docker exec $userflag $container_name /bin/sh -c '
#sudo rm -f /bin/python /bin/python3 && 
#sudo ln -sf $(which python) /bin/python && 
#sudo ln -sf $(which python) /bin/python3 &&
#echo "Python symlinks updated:" &&
#ls -la /bin/python* &&
#/bin/python --version
#'
## ..in fact, better the the user does all that in the container by him/herself with:
## setup_debugpy.bash
#
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
  docker exec $userflag $container_name /bin/sh -c '
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

if [ "$SAMPSA" = true ]; then
  echo "APPLYING SAMPSA'S SPECIFIC CONFIGS"
  docker exec $userflag -it $container_name /bin/bash -c '
  echo "(setq make-backup-files nil)" > /root/.emacs
  '
fi

if [ "$LATEST" = true ]; then
  echo
  echo "INSTALLING & COMPILING LATEST PYTORCH AND TRITON 3.3.x"
  echo
  ## install latest pytorch main and triton tot:
  ## tot would be: install_triton.bash --head &&
  #docker exec $userflag -it $container_name /bin/bash -c '
  #  PS1=dummy source ~/.bashrc &&
  #  install_triton.bash 3.3.x &&
  #  get_torch_me.bash &&
  #  cd /root/pytorch-me &&
  #  clean_torch.bash --yes &&
  #  setpytorch.bash me
  #  '
  ## in parallel:
  docker exec $userflag -it $container_name /bin/bash -c '
    PS1=dummy source ~/.bashrc &&
    install_triton.bash 3.3.x &
    get_torch_me.bash &&
    cd /root/pytorch-me &&
    clean_torch.bash --yes &
    wait &&
    cd /root/pytorch-me &&
    initlinter.bash --yes &&
    setpytorch.bash me
  '
fi
echo
echo "DONE!"
echo
