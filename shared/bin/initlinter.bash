#/bin/bash
echo
echo will create pristine python env into ./venv/
echo and then run lintrunner init within that environment
echo you typically want to do this at
echo "/var/lib/jenkings/pytorch (internal testing image)"
echo or at
echo "/tmp/pytorch (nightly)"
echo
read -p "Press enter to continue, CTRL-C to abort"
if [ -d "venv" ]; then
    echo "lintrunner venv directory exists already"
else
    export PYTHONNOUSERSITE=1
    export PIP_NO_CACHE_DIR=1
    echo "will create venv and install lintrunner therein"
    python -m venv ./venv
    ./venv/bin/pip install lintrunner
    echo "Installing required linters"
    ./venv/bin/lintrunner init
    echo "Installed required linters"
    unset PYTHONNOUSERSITE
    unset PIP_NO_CACHE_DIR
fi
