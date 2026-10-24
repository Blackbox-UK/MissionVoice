#!/usr/bin/env bash
# Findings folded in (24 Oct): TLS must be asked for with sip_transports; loopback needs net_interface as an
# address, not "lo"; Baresip opus is 48 kHz/2 ch internally, so the test source runs at 48 kHz with auresamp.
# Two Baresip instances (mvt-a, mvt-b): SIP over TLS 1.3 to FreeSWITCH, DTLS-SRTP, Opus, no sound card
# (sine source, file sink), controlled over ctrl_tcp. The real MVT runtime will drive Baresip the same way.
set -euo pipefail
T=${MV_TEST_ROOT:-/home/claude/fsbuild}/test; PKI=${MV_TEST_ROOT:-/home/claude/fsbuild}/pki
PW_A=$(sed -n 1p $T/sip.pw); PW_B=$(sed -n 2p $T/sip.pw)
mk() { # name, password, ctrl port, sip local port
  local d=$T/baresip-$1; rm -rf $d; mkdir -p $d
  cat > $d/config <<CFG
sip_listen		127.0.0.1:$4
sip_certificate		$PKI/$1.pem
sip_cafile		$PKI/ca.crt
sip_verify_server	yes
sip_trans_def		tls
sip_transports		tls
net_interface		127.0.0.1
audio_player		aufile,$d/rx.wav
audio_source		ausine,440
audio_srate		48000
ausrc_srate		48000
auplay_srate		48000
audio_channels		1
rtp_ports		30000-30999
module_path		/usr/local/lib/baresip/modules
module			opus.so
module			ausine.so
module			aufile.so
module			auresamp.so
module			dtls_srtp.so
module			ctrl_tcp.so
module_app		account.so
module_app		menu.so
ctrl_tcp_listen		127.0.0.1:$3
opus_bitrate		28000
opus_cbr		yes
opus_inbandfec		no
opus_dtx		no
dtls_srtp_use_ec	secp384r1
CFG
  echo "<sip:$1@127.0.0.1;transport=tls>;auth_pass=$2;mediaenc=dtls_srtp;answermode=auto;regint=120;ptime=20;audio_codecs=opus/48000/2" > $d/accounts
}
mk mvt-a "$PW_A" 4444 5080
mk mvt-b "$PW_B" 4445 5081
echo BARESIP_CONF_OK
