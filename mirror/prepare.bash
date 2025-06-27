#!/bin/bash
## run at CLIENT to prepare a new remote server
## we want to use bash as our default shell & also check if the user's home directory is broken and if so, then fix it (it's AMD!)
ssh -o StrictHostKeyChecking=no -p "$sshport" $username@"$hostname" '
if [ ! -f ~/.bashrc ]; then
    cp /etc/skel/.bashrc ~/.bashrc && echo ".bashrc copied from /etc/skel"
else
    echo ".bashrc already exists"
fi

if [ ! -f ~/.bash_profile ]; then
    echo "if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi" > ~/.bash_profile && echo ".bash_profile created"
else
    echo ".bash_profile already exists"
fi
'
echo "modding .bashrc"  # Fixed typo in echo message
ssh -p "$sshport" $username@"$hostname" 'echo "
# If not running interactively, dont do anything
case \$- in
    *i*) ;;
      *) return;;
esac" >> ~/.bashrc'
ssh -p "$sshport" $username@"$hostname" 'echo "source mirror/env.bash" >> ~/.bashrc'
ssh -p "$sshport" $username@"$hostname" "echo \"export gitname=$gitname\" >> ~/.bashrc"
# ssh -p "$sshport" $username@"$hostname" 'echo "source mirror/context/'$contextname'.bash" >> ~/.bashrc' # NOT THIS!  login script will take care of this
echo "making some directories"
ssh -p "$sshport" $username@"$hostname" 'mkdir -p mirror && mkdir -p shared/env && mkdir -p shared/pythonenv && mkdir -p shared/notebook && mkdir -p shared/script && mkdir -p shared/bin && mkdir -p sharedump'
## NOTE: we take env variables from the local environment (but they should be same at the remote):
echo "configuring git, tmux and emacs"
ssh -p "$sshport" "$username@$hostname" "
git config --global user.name '${gitname}' &&
git config --global user.email '${gitemail}' &&
cat << EOF > \$HOME/.tmux.conf
set -g mouse on
# Enable xterm-style key sequences
set-window-option -g xterm-keys on
# Enable focus events (helps with editor integration)
set -g focus-events on
EOF
cat << EOF > \$HOME/.emacs.d/init.el
;; Disable backup files
(setq make-backup-files nil)
(setq backup-inhibited t)
(setq auto-save-default nil)
EOF
"
echo "apt-get/yum installing some"
# keep in mind that this might be redhat or even centos! -> use yum
#ssh -p "$sshport" $username@"$hostname" '
#sudo apt-get update && 
#sudo apt-get install -y inotify-tools emacs dialog tmux silversearcher-ag iputils-ping zip ||
#sudo yum install -y inotify-tools emacs dialog tmux silversearcher-ag iputils zip
#'
ssh -p "$sshport" $username@"$hostname" '
if command -v apt-get >/dev/null 2>&1; then
    echo "Detected Debian/Ubuntu - using apt-get"
    sudo apt-get update && sudo apt-get install -y inotify-tools emacs dialog tmux silversearcher-ag iputils-ping zip
elif command -v yum >/dev/null 2>&1; then
    echo "Detected RedHat/CentOS - using yum"
    sudo yum install -y inotify-tools emacs dialog tmux silversearcher-ag iputils zip
elif command -v dnf >/dev/null 2>&1; then
    echo "Detected Fedora - using dnf"
    sudo dnf install -y inotify-tools emacs dialog tmux silversearcher-ag iputils zip
else
    echo "No supported package manager found!"
    exit 1
fi
'
# this is needed for modern debians/ubuntus:
ssh -p "$sshport" $username@"$hostname" '
sudo apt install python3-venv
'
echo "sending custom ssh keys"
scp -P $sshport -r custom_ssh_keys $username@$hostname:
echo "setting custom ssh key rights"
ssh -p "$sshport" $username@"$hostname" '
mkdir -p .ssh && 
cp custom_ssh_keys/id_rsa .ssh/ && 
cp custom_ssh_keys/id_rsa.pub .ssh/ && 
chmod 600 ~/.ssh/id_rsa && 
chmod 644 ~/.ssh/id_rsa.pub
'
echo "Checking GPU type and installing DLM..."
ssh -p "$sshport" $username@"$hostname" '
    # Function to detect GPU vendor
    detect_gpu_vendor() {
        if command -v rocminfo &> /dev/null && rocminfo &> /dev/null; then
            echo "amd"
        elif command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
            echo "nvidia"
        else
            echo "none"
        fi
    }

    # Get GPU vendor
    GPU_VENDOR=$(detect_gpu_vendor)
    echo "Detected GPU vendor: $GPU_VENDOR"

    if [ "$GPU_VENDOR" = "amd" ]; then
        echo "AMD GPU detected, proceeding with ROCm DLM installation..."
        GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git clone --depth 1 git@github.com:ROCm/DeepLearningModels.git &&
        cd DeepLearningModels &&
        python3 -m venv venv &&
        venv/bin/pip install -r requirements.txt
        echo
        echo IF YOU RUN DLM DO IT IN THE VIRTUALENV
        echo
    else
        echo "No AMD GPU detected, skipping DLM installation"
        exit 1
    fi
'

# Check the SSH command's exit status
if [ $? -eq 0 ]; then
    echo "Installation completed successfully"
else
    echo "Installation skipped or failed"
fi
echo
echo "DONE!"
echo
