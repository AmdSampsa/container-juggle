#!/bin/bash
## let's ask for sudo in the very beginning, so it wont as it again
sudo killall -9 sshfs
fusermount -u ~/remote_shared
sshfs -p $sshport -o allow_other,default_permissions,uid=$(id -u),gid=$(id -g) $username@$hostname:shared ~/remote_shared
read -p "SSHFS mounted - press enter to unmount"
fusermount -u ~/remote_shared
# kill any hanging processes
killall -9 sshfs
# unmount and remount network folders
sudo umount -a -t nfs,cifs
sudo mount -a -t nfs,cifs
