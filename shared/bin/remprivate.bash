#!/bin/bash
## safely remove & overwrite your private ssh key
shred -u ~/.ssh/id_rsa
shred -u ~/.ssh/id_rsa.pub
shred -u ~/.ssh/authorized_keys
shred -u ~/.ssh/known_hosts*
## remove global git config
rm ~/.gitconfig
