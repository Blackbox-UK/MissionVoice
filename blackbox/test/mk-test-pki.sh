#!/usr/bin/env bash
# Throwaway TEST PKI for the S1 bench. ECDSA P-384 / SHA-384 (algorithm profile, D49).
# NOT the Mission Voice CA (docs/KEY_MANAGEMENT.md): keys live only in the output directory.
#   mk-test-pki.sh <out-dir> <mvc-address> <terminal-id> [<terminal-id> ...]
# Produces: ca.crt ca.key; mvc.{crt,key,pem}; <terminal>.{crt,key,pem}; and the FreeSWITCH names
# agent.pem cafile.pem dtls-srtp.pem (copies of mvc.pem / ca.crt).
set -euo pipefail
OUT=${1:?out dir}; MVC=${2:?mvc address or name}; shift 2
[ $# -ge 1 ] || { echo "at least one terminal id" >&2; exit 2; }
mkdir -p "$OUT" && cd "$OUT"
ec() { openssl ecparam -name secp384r1 -genkey -noout -out "$1"; }
[ -f ca.key ] || { ec ca.key; openssl req -x509 -new -key ca.key -sha384 -days 30 \
  -subj "/O=Blackbox-UK TEST/CN=Mission Voice TEST CA" \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" -out ca.crt; }
issue() { # name, CN, SAN, EKU
  ec "$1.key"
  openssl req -new -key "$1.key" -sha384 -subj "/O=Blackbox-UK TEST/CN=$2" -out "$1.csr"
  printf "basicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=%s\nsubjectAltName=%s\n" "$4" "$3" > "$1.ext"
  openssl x509 -req -in "$1.csr" -CA ca.crt -CAkey ca.key -CAcreateserial -sha384 -days 30 -extfile "$1.ext" -out "$1.crt" 2>/dev/null
  cat "$1.crt" "$1.key" > "$1.pem"; chmod 600 "$1.key" "$1.pem"; rm -f "$1.csr" "$1.ext"
}
if [[ "$MVC" =~ ^[0-9.]+$ ]]; then SAN="IP:$MVC,DNS:mvc.test"; else SAN="DNS:$MVC,DNS:mvc.test"; fi
issue mvc "$MVC" "$SAN" "serverAuth,clientAuth"
for t in "$@"; do issue "$t" "$t" "DNS:$t.test" "clientAuth"; done
cp mvc.pem agent.pem; cp ca.crt cafile.pem; cp mvc.pem dtls-srtp.pem; chmod 600 agent.pem dtls-srtp.pem
echo "test PKI in $OUT: CA, mvc ($SAN), terminals: $*"
