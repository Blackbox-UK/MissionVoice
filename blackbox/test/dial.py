#!/usr/bin/env python3
"""Drive a test Baresip over ctrl_tcp and read the negotiated crypto from FreeSWITCH.
usage: dial.py <ctrl_port> <sip uri> [hold seconds]"""
import json, socket, subprocess, sys, time, os
T = os.environ.get("MV_TEST_ROOT", "/home/claude/fsbuild") + "/test"
PREFIX = os.environ.get("PREFIX", "/opt/missionvoice/freeswitch")
ns = lambda b: b"%d:%s," % (len(b), b)
pw = open(T + "/esl.pw").read().strip()
fs = lambda c: subprocess.run([PREFIX + "/bin/fs_cli", "-p", pw, "-x", c], capture_output=True, text=True).stdout.replace("\r", "")
port, uri = int(sys.argv[1]), sys.argv[2]
hold = float(sys.argv[3]) if len(sys.argv) > 3 else 5.0
s = socket.create_connection(("127.0.0.1", port)); s.settimeout(0.5)
s.sendall(ns(json.dumps({"command": "dial", "params": uri, "token": "dial"}).encode()))
time.sleep(hold)
rows = [l.split("|") for l in fs("show channels as delim |").splitlines()[1:] if "|" in l and len(l.split("|")[0]) == 36]
print("channels up:", len(rows))
for r in rows:
    v = {l.split(": ", 1)[0]: l.split(": ", 1)[1] for l in fs("uuid_dump " + r[0]).splitlines() if ": " in l}
    print("  %-9s %-16s crypto=%-28s via=%-4s codec=%s" % (
        v.get("variable_direction", "?"), v.get("variable_sip_from_user", "?") + "->" + v.get("variable_sip_to_user", "?"),
        v.get("variable_rtp_has_crypto", "-").replace("%3A", ":"), v.get("variable_sip_via_protocol", "?"), v.get("variable_read_codec", "?")))
s.sendall(ns(json.dumps({"command": "hangup", "token": "hangup"}).encode())); time.sleep(1); s.close()
