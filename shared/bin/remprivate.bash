#!/bin/bash
if [ ! -f /.dockerenv ]; then
    echo "Error: This script must be run inside a Docker container" >&2
    exit 1
fi
echo "Removing your ssh keys and global git config"
## safely remove & overwrite your private ssh key
shred -u ~/.ssh/id_rsa
shred -u ~/.ssh/id_rsa.pub
shred -u ~/.ssh/authorized_keys
shred -u ~/.ssh/known_hosts*
## remove global git config
rm ~/.gitconfig
echo "Done!"
echo "You can always reinstall, by running OUTSIDE the container"
echo "install_private.bash"
echo
