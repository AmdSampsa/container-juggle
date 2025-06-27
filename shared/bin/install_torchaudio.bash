#!/bin/bash
git clone https://github.com/pytorch/audio.git $HOME/torchaudio
cd $HOME/torchaudio

# For development builds, it's better to get the main branch or a commit that matches your PyTorch timeframe
# git checkout --shallow-since="2 years ago" main  # Or use a specific commit that's aligned with your PyTorch commit # takes too long..
git checkout --shallow-since="1 years ago" main  # Or use a specific commit that's aligned with your PyTorch commit

# Install from source
pip uninstall -y torchaudio  # Remove the pip-installed version first
python setup.py install  # Or use `pip install -e .` for a development install
