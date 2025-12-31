#!/usr/bin/env bash
set -ex

ARCHITECTURE="$(uname -m)"

sudo yum install -y bzip2

curl -fLSs "https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-${ARCHITECTURE}.sh" -o miniconda_installer.sh

bash miniconda_installer.sh -b -f -p /home/ec2-user/miniconda
CONDA_PLUGINS_AUTO_ACCEPT_TOS=true /home/ec2-user/miniconda/bin/conda install -c conda-forge -y awscli
rm miniconda_installer.sh