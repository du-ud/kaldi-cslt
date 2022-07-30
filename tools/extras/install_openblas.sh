#!/usr/bin/env bash

OPENBLAS_VERSION=0.3.13

WGET=${WGET:-wget}

set -e

if ! command -v gfortran 2>/dev/null; then
  echo "$0: gfortran is not installed.  Please install it, e.g. by:"
  echo " apt-get install gfortran"
  echo "(if on Debian or Ubuntu), or:"
  echo " yum install gcc-gfortran"
  echo "(if on RedHat/CentOS).  On a Mac, if brew is installed, it's:"
  echo " brew install gfortran"
  exit 1
fi


tarball=OpenBLAS-$OPENBLAS_VERSION.tar.gz

rm -rf xianyi-OpenBLAS-* OpenBLAS
if [ ! -d ./extras ]; then
  errcho "****** You are trying to install OPENBLAS from the wrong directory.  You should"
  errcho "****** go to tools/ and type extras/install_openblas.sh."
  exit 1
fi

if [ -f $tarball ]; then
  echo "$tarball already exits."
else
  url=$($WGET -qO- "https://api.github.com/repos/xianyi/OpenBLAS/releases/tags/v${OPENBLAS_VERSION}" | python -c 'import sys,json;print(json.load(sys.stdin)["tarball_url"])')
  test -n "$url"
  $WGET -t3 -nv -O $tarball "$url"
fi

tar xzf $tarball
mv xianyi-OpenBLAS-* OpenBLAS

make PREFIX=$(pwd)/OpenBLAS/install USE_LOCKING=1 USE_THREAD=0 -C OpenBLAS all install
if [ $? -eq 0 ]; then
   echo "OpenBLAS is installed successfully."
fi
