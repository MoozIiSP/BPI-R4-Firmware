#!/bin/bash
set -euo pipefail

# Install the build dependencies required by OpenWrt on GitHub-hosted
# Ubuntu runners. Keep this in one place so build and release workflows stay
# aligned.

if [ "$(id -u)" = "0" ]; then
  SUDO=""
else
  SUDO="sudo -E"
fi

export DEBIAN_FRONTEND=noninteractive

$SUDO apt-get -o Acquire::Languages=none update -qq
$SUDO apt-get install -y -qq --no-install-recommends \
  asciidoc bash bin86 binutils bison bzip2 clang file flex g++ g++-multilib gawk \
  gcc-multilib gettext git curl gzip help2man intltool jq libbpf-dev libelf-dev \
  libncurses-dev libssl-dev libthread-queue-any-perl libusb-dev libxml-parser-perl \
  make patch perl-modules pkg-config python3-dev python3-pip python3-pyelftools \
  python3-setuptools rsync sharutils swig time unzip util-linux wget xsltproc \
  xz-utils zlib1g-dev zip zstd dwarves dos2unix bc llvm quilt

python3 -m pip install --user -U pylibfdt --break-system-packages
