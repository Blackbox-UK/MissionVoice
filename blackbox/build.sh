#!/usr/bin/env bash
# Mission Voice FreeSWITCH build (MV-FS-004). Reproducible: no network fetches, no autodetected extras.
# Run on the MVC host (Ubuntu 24.04 / 26.04) with the build dependencies installed from the release media.
set -euo pipefail

PREFIX=${PREFIX:-/opt/missionvoice/freeswitch}
JOBS=${JOBS:-$(nproc)}
SRC=$(cd "$(dirname "$0")/.." && pwd)

cd "$SRC"
test -f blackbox/UPSTREAM_PIN
cp build/modules.conf.missionvoice modules.conf

# bootstrap without touching the network
./bootstrap.sh -j

# --enable-openssl is forwarded to libs/srtp by AC_CONFIG_SUBDIRS; the top-level configure ignores it.
# Without it libsrtp has no AES-GCM cipher registered and SRTP does not use the OpenSSL provider (FIPS).
./configure \
  --prefix="$PREFIX" \
  --enable-openssl \
  --enable-core-pgsql-support \
  --disable-core-odbc-support \
  --disable-libyuv --disable-libvpx \
  --without-python3 --without-erlang \
  --enable-zrtp=no \
  CFLAGS="-O2 -g0 -fstack-protector-strong -D_FORTIFY_SOURCE=2 -fPIE" \
  LDFLAGS="-Wl,-z,relro,-z,now -pie"

make -j"$JOBS"
make install

# Configuration tree and OpenSSL profile.
# `make install` has just laid down FreeSWITCH's vanilla conf (internal/external SIP profiles with
# clear-text UDP/TCP listeners, voicemail, IVR menus, ...). It must not survive: the Mission Voice tree
# REPLACES it (MV-FS-003), it does not overlay it. Found on the first build, 24 Oct 2026.
rm -rf "$PREFIX/etc/freeswitch"
install -d "$PREFIX/etc/freeswitch"
cp -r conf/missionvoice/. "$PREFIX/etc/freeswitch/"
test "$(ls "$PREFIX/etc/freeswitch/sip_profiles")" = "missionvoice.xml" || { echo "unexpected SIP profiles installed" >&2; exit 1; }
install -m 0644 blackbox/openssl-missionvoice.cnf "$PREFIX/etc/freeswitch/openssl.cnf"

# Record what was built
{
  echo "upstream_pin=$(head -1 blackbox/UPSTREAM_PIN)"
  echo "blackbox_commit=$(git rev-parse HEAD)"
  echo "modules=$(grep -vE "^#|^$" modules.conf | tr "\n" " ")"
  echo "built=$(date -u +%FT%TZ)"
  echo "freeswitch_sha256=$(sha256sum "$PREFIX/bin/freeswitch" | cut -d' ' -f1)"
} > "$PREFIX/BUILD_RECORD"
cat "$PREFIX/BUILD_RECORD"
