#!/bin/bash
export PATH=$PATH:$HOME/mirror:$HOME/shared/bin:$HOME/DeepLearningModels/tools
## better prompt
export PS1='[\h:$contextname]/\W> '
## command for choosing the context with a gui
alias slct='source ~/mirror/slct.bash'
alias slc="source ~/.latest_ctx.bash && echo \$contextname >> $HOME/.slct_history.txt  "
alias lg="source ~/.latest_ctx.bash && echo \$contextname >> $HOME/.slct_history.txt && login.bash"
alias tlg='source ~/.latest_ctx.bash && tlogin.bash'
# alias tls="ssh -p\$sshport \$username@\$hostname tmux ls 2>/dev/null | grep '^${contextname}\-'" # TODO: should load the contextfile at the most
alias tlsa="ssh -p\$sshport \$username@\$hostname tmux ls 2>/dev/null"
# alias tlgnew='source ~/.latest_ctx.bash && tloginew.bash' # nopes
alias slast="source ~/.latest_ctx.bash && echo \$contextname >> $HOME/.slct_history.txt "
alias shis="tac $HOME/.slct_history.txt"
##
#echo
#echo "*****REMEMBER TO LOAD A CONTEXT*****"
#echo "i.e.:"
#echo "source mirror/context/ctxname.bash"
#echo "or even better: type 'slct' and press enter"
#echo "************************************"
#echo "available contexes:"
#ls -1 mirror/context
#echo
extract_to_subdir() {
  local filename="$1"
  local zipfile="${filename}.zip"
  local subdir="${filename}"
  
  # Check if the zip file exists
  if [ ! -f "$zipfile" ]; then
    echo "Error: $zipfile does not exist."
    return 1
  fi
  
  # Create subdirectory if it doesn't exist
  mkdir -p "$subdir"
  
  # Unzip the file into the subdirectory
  unzip -o "$zipfile" -d "$subdir"
  
  echo "Successfully extracted $zipfile to $subdir/"
}

# Create the alias that calls the function
alias unzipsub='extract_to_subdir'

