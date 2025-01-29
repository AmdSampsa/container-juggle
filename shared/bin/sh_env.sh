#!/bin/sh
set -a  # This makes all subsequently defined variables be exported
. /root/shared/bin/contenv.bash
. /root/shared/bin/buildenv.bash
## this wont work from the bash side:
alias runprofd='python /var/lib/jenkins/rocmProfileData/tools/$@'
set +a  # Stop auto-exporting
