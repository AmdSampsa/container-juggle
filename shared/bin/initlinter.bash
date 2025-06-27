#/bin/bash
echo
echo will create pristine python env into ./venv/
echo and then run lintrunner init within that environment
echo you typically want to do this at
echo "/var/lib/jenkings/pytorch (internal testing image)"
echo or at
echo "/tmp/pytorch (nightly)"
echo
if [ "$1" != "--yes" ]; then
    read -p "Press enter to continue, CTRL-C to abort"
    if [ -d "venv" ]; then
        while true; do
            read -p "venv directory exists. Remove and continue? (y/n): " yn
            case $yn in
                [Yy]* ) rm -rf venv; break;;
                [Nn]* ) echo "Exiting..."; exit 1;;
                * ) echo "Please answer y or n.";;
            esac
        done
    fi
fi
export PYTHONNOUSERSITE=1
export PIP_NO_CACHE_DIR=1
echo "will create venv and install lintrunner therein"
python -m venv ./venv
export VIRTUAL_ENV=$(pwd)/venv
./venv/bin/pip install lintrunner
echo "Installing required linters"
./venv/bin/lintrunner init
echo "Installed required linters"
unset PYTHONNOUSERSITE
unset PIP_NO_CACHE_DIR
