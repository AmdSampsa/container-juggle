#!/bin/bash
export contextname=
## NOTE: contextname should always be the same as the name of the script
## for example: scriptname: play1.bash -> contextname=play1
## use at both SERVER and CLIENT
## set env variables both at client & server side
## used at the server side:
export username= ## ditto
export container_name=  ## the name you'll be giving to the running container ## TIP: add your username to the container name for easier identification
export image_id= ## name of the docker image
## used at the client side:
export hostname= ## name of your remote host
export hostnick= ## host nickname .. for vscode etc.
export sshport=22 ## port for ssh connections
## set terminal title
echo -e "\033]0;"$contextname"\007"
export PRINCIPAL_DIR="/path/to/your/project"
