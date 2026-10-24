#!/usr/bin/env bash
# Throwaway test PKI for the hop-by-hop SRTP test. ECDSA P-384 / SHA-384 (algorithm profile, D49).
# NOT the Mission Voice CA (docs/KEY_MANAGEMENT.md); keys live only in this directory and are deleted after.
set -euo pipefail
cd "$(dirname "$0")"
ec() { openssl ecparam -name secp384r1 -genkey -noout -out "$1"; }
ec ca.key
openssl req -x509 -new -key ca.key -sha384 -days 2 -subj "/O=Blackbox-UK TEST/CN=Mission Voice TEST CA" \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" -out ca.crt
issue() { # name, CN, SAN, extendedKeyUsage
  ec "$1.key"
  openssl req -new -key "$1.key" -sha384 -subj "/O=Blackbox-UK TEST/CN=$2" -out "$1.csr"
  printf "basicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=%s\nsubjectAltName=%s\n" "$4" "$3" > "$1.ext"
  openssl x509 -req -in "$1.csr" -CA ca.crt -CAkey ca.key -CAcreateserial -sha384 -days 2 -extfile "$1.ext" -out "$1.crt"
  cat "$1.crt" "$1.key" > "$1.pem"
}
issue mvc   "mvc.test"        "DNS:mvc.test,IP:127.0.0.1" "serverAuth,clientAuth"
issue mvt-a "mvt-a.test"      "DNS:mvt-a.test"           "clientAuth"
issue mvt-b "mvt-b.test"      "DNS:mvt-b.test"           "clientAuth"
# FreeSWITCH/sofia layout: agent.pem = server cert+key, cafile.pem = trust, dtls-srtp.pem = DTLS identity
cp mvc.pem agent.pem; cp ca.crt cafile.pem; cp mvc.pem dtls-srtp.pem
openssl x509 -in mvc.crt -noout -subject -ext subjectAltName | tr '\n' ' '; echo
