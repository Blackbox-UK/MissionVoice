#!/usr/bin/env bash
# Build dependencies for the Mission Voice FreeSWITCH fork on Ubuntu 24.04 (A16 evidence).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -q --no-install-recommends \
  build-essential autoconf automake libtool pkg-config cmake git yasm \
  libssl-dev libpcre3-dev libedit-dev libsqlite3-dev libcurl4-openssl-dev \
  libpq-dev zlib1g-dev libspeexdsp-dev libspeex-dev libopus-dev libsndfile1-dev \
  libtiff-dev libjpeg-dev uuid-dev libldns-dev libtool-bin python3-dev \
  libavformat-dev libswscale-dev libshout3-dev libmpg123-dev libmp3lame-dev \
  libgumbo-dev 2>&1 | tail -2 || true
# the two libraries FreeSWITCH requires from its own forks
cd ${MV_TEST_ROOT:-/home/claude/fsbuild}
for repo in sofia-sip spandsp; do
  [ -d $repo ] || git clone -q --depth 1 https://github.com/freeswitch/$repo.git
done
cd sofia-sip && ( [ -f Makefile ] || ./bootstrap.sh -j ) && ./configure -q --prefix=/usr/local && make -j2 -s && make install -s && ldconfig
cd ../spandsp && ( [ -f Makefile ] || ./bootstrap.sh -j ) && ./configure -q --prefix=/usr/local && make -j2 -s && make install -s && ldconfig
echo DEPS_OK
