#!/usr/bin/env bash
# Start the test FreeSWITCH detached. -certs points at the test PKI copy; in production the service
# unit passes -certs /etc/missionvoice/tls (FreeSWITCH otherwise uses <conf>/tls).
T=${MV_TEST_ROOT:-/home/claude/fsbuild}/test
PREFIX=${PREFIX:-/opt/missionvoice/freeswitch}
cd "$T" && rm -rf log db run && mkdir -p log db run
OPENSSL_CONF=$PREFIX/etc/freeswitch/openssl.cnf nohup setsid $PREFIX/bin/freeswitch -nc -nf -nonat \
  -conf "$T/conf" -log "$T/log" -db "$T/db" -run "$T/run" -certs "$T/certs" > fs.out 2>&1 < /dev/null &
echo $! > fs.pid
