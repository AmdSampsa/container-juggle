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
