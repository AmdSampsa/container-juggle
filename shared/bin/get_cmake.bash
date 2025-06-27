#!/bin/bash
if [ -z "$1" ]; then
    echo "Error: release tag missing"
    echo "use 3.18.0 (for oldie) or 3.27.0 (for newbie)"
    exit 1
fi
cd $HOME
# ver="3.18.0" # oold PTs need this
# ver="3.27.0" # more recent PTs want this
ver=$1
# download
wget https://github.com/Kitware/CMake/releases/download/v$ver/cmake-$ver-linux-x86_64.tar.gz
# Extract and use:
tar -xzf cmake-$ver-linux-x86_64.tar.gz
sudo cp cmake-$ver-linux-x86_64/bin/* /usr/local/bin/
sudo cp -r cmake-$ver-linux-x86_64/share/* /usr/local/share/
# Update PATH and test:
hash -r
which cmake
cmake --version
exit 0
##
##
## below: too complicated & slow & probably doesnt even work
##
wget https://github.com/Kitware/CMake/archive/refs/tags/v$ver.zip
unzip v$ver.zip
cd CMake-$ver
./bootstrap --no-system-libs && make -j 8 && sudo make install
if [ $? -ne 0 ]; then
echo
echo FAILED
echo
exit 1
fi
sudo apt-get remove cmake --yes
mv /opt/conda/envs/py_3.10/bin/cmake /opt/conda/envs/py_3.10/bin/cmake.bak
ln -s /usr/local/bin/cmake /opt/conda/envs/py_3.10/bin/cmake
# referesh file paths:
hash -r
echo
echo lets test
echo
which cmake
echo
cmake --version
echo
##if fails, try:
##sudo rm -f /usr/local/bin/cmake
##sudo rm -rf /usr/local/share/cmake*
