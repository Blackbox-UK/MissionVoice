# Blackbox-UK/MissionVoice: the Mission Voice fork of FreeSWITCH

This repository is the FreeSWITCH used inside the Mission Voice Core (MVC).
It is upstream `signalwire/freeswitch` plus a small, named set of Blackbox
changes. Nothing here is a product by itself; the MVC controller (separate
repository) owns every decision FreeSWITCH acts on.

## Branches

| Branch | Contents | Rule |
|---|---|---|
| `master` | Upstream `signalwire/freeswitch` master, byte for byte. | Never commit to it. Fast-forward from upstream only. |
| `blackbox` | `master` plus the Blackbox commits below, rebased onto the pinned upstream commit. | Every change is one commit with an `MV-FS-nnn` identifier in its subject and a reason in its body. |
| `release/<version>` | A tagged, frozen `blackbox` for a release bundle (P26). | Tag is `mv-fs-<version>`; the bundle records the hash. |

Upstream security fixes arrive on `master`; `blackbox` is rebased onto
them and the Blackbox commits re-applied. Keeping the set small is the
point.

## The Blackbox changes

| ID | Change | Why | Status |
|---|---|---|---|
| MV-FS-001 | `src/switch_rtp.c`: DTLS-SRTP negotiates `SRTP_AEAD_AES_256_GCM` (and AES-128-GCM, AES-128-CM as fallbacks), reads the selected profile, sizes keys from it, reports it in `rtp_has_crypto` and `CALL_SECURE`; channel variable `rtp_dtls_srtp_profiles` narrows the offer. Upstream hard-wires AES-128-CM/HMAC-SHA1-80. | D05, D49: AES-256 and SHA-2 on every leg; `mvc-key-management.md` section 2. | **Built and verified 24 Oct 2026**: `rtp_has_crypto = srtp:dtls:AEAD_AES_256_GCM` on inbound and outbound legs against Baresip 4.12 (`blackbox/test/`). |
| MV-FS-002 | `build/modules.conf.missionvoice`: the module set. Twelve modules; `mod_signalwire`, `mod_enum`, `mod_httapi`, CDR modules, scripting and every codec but Opus are not built. | D46: no beacons (`mod_signalwire` connects to SignalWire's cloud); attack surface. | Written. |
| MV-FS-003 | `conf/missionvoice/`: the configuration tree. One SIP profile, TLS 1.3 only, mutual TLS, no clear-text listener, SRTP AEAD only, Opus CBR without DTX, ESL on loopback, no core dumps, no debug logging, directory and dialplan from the controller, static fallback that refuses everything. | E2EE analysis F3, F7, F8, section 1a; P25; D48. | Written. |
| MV-FS-004 | `blackbox/build.sh` and `blackbox/openssl-missionvoice.cnf`: reproducible build passing `--enable-openssl` through to the bundled libsrtp (without it there is no AES-GCM at all and SRTP is not on the OpenSSL provider), and the OpenSSL configuration the FreeSWITCH process runs under (TLS 1.3 suites and groups pinned; FIPS and TPM providers switched on when present). | E2EE analysis F2, F4. | Written; build to be run on the MVC host. |
| MV-FS-005 | `mod_sofia`: expose the verified TLS client certificate's subject and SHA-256 fingerprint as channel variables and pass them in the `mod_xml_curl` directory lookup. | E2EE analysis F3 identity-binding gap; D48. | Not started; S2. |
| MV-FS-006 | `src/switch_core_cert.c`: never generate a self-signed RSA-4096 `dtls-srtp.pem`; refuse to start DTLS without an installed device certificate. | F5; `mvc-key-management.md` rule 1. Root cause found on the first run: `switch_core_check_dtls_pem` applied an RSA rule (`bits < 4096` ⇒ regenerate) that rejects every EC key, renamed the installed P-384 certificate aside and minted RSA-4096; `switch_msrp.c` and `sofia.c` generated `wss.pem`/`tls.pem`. All four generators removed; EC ≥ 256 / RSA ≥ 3072 accepted; nothing is ever renamed or generated. | **Done 24 Oct 2026** (brought forward from S2: it blocked the S1 hop test). |
| MV-FS-007 | `src/switch_core_media.c` `get_media_profile_name`: an outbound offer carrying a DTLS fingerprint (`rtp_use_dtls=true`) is labelled `UDP/TLS/RTP/SAVP` (RFC 5764 §8) instead of `RTP/AVP`. Upstream's label makes a conforming endpoint reject the offer ("no DTLS under AVP": Baresip answered 488). | Direct calls and every FreeSWITCH-originated leg (D31, P18). | **Done 24 Oct 2026.** |
| MV-FS-008 | `blackbox/build.sh`: `make install` lays down FreeSWITCH's vanilla configuration (internal/external SIP profiles with clear-text listeners, voicemail, IVR); the Mission Voice tree now **replaces** it rather than overlaying it, and the build fails if any SIP profile but `missionvoice.xml` is present. `build/modules.conf.missionvoice`: FreeSWITCH's module Makefile treats a single `#` as a disabled module and only `##` as a comment; the file was reformatted. | MV-FS-003 would have been silently undone on a real MVC; the leaked `external-ipv6` profile failing to bind took `mod_sofia` down. | **Done 24 Oct 2026.** |

What FreeSWITCH keeps doing in Mission Voice, and for how long, is decided
by the G1 spike (handover v0.2 section 7.2): under D97 group media moves
to the key-blind relay, so `mod_conference` is interim.

## Upstream pin

The pinned upstream commit is recorded in `blackbox/UPSTREAM_PIN`: the
commit this branch was cut from, and the authoritative S1 build pin (D102,
A16). There is no earlier Mission Voice build to inherit a pin from. Moving
the pin is a reviewed change with a rebase of the MV-FS-* patches.

## Building

See `blackbox/build.sh`. The build is reproducible: same pin, same module
list, same configure flags, same compiler, same output hash recorded in
the release manifest (P26).

## Hop-by-hop SRTP test, 24 October 2026

The fork was built for the first time (`blackbox/deps-ubuntu-24.04.sh`,
then `blackbox/build.sh`; BUILD_RECORD in the install prefix) and tested
against Baresip 4.12.0 built from source, on one Ubuntu 24.04 host over
loopback, with a throwaway EC P-384 test PKI (`blackbox/test/mk-test-pki.sh`;
never the Mission Voice CA). Scripts in `blackbox/test/` reproduce it.

Results:

| Check | Result |
|---|---|
| SIP/TLS listener | TLS 1.3 only (TLS 1.2 refused with `protocol version`); `TLS_AES_256_GCM_SHA384`; ECDH secp384r1; ECDSA/SHA-384; no clear-text port 5060. |
| Mutual TLS registration | Baresip registered over TLS with its client certificate; `Registered(TLS)`. |
| Terminal → FreeSWITCH echo | FreeSWITCH `rtp_has_crypto = srtp:dtls:AEAD_AES_256_GCM`, `rtp_secure_media = mandatory`; Baresip `DTLS-SRTP complete Profile=AEAD_AES_256_GCM` for RTP and RTCP, fingerprint verified; DTLS `ECDHE-ECDSA-AES256-GCM-SHA384`. |
| Wire | DTLS handshake records then SRTP: 98-byte UDP payloads at 50 pps = 12 B RTP header + 70 B Opus (28 kbit/s CBR, 20 ms) + 16 B GCM tag; nothing else. |
| Terminal → terminal through FreeSWITCH | Both legs `srtp:dtls:AEAD_AES_256_GCM`; four SRTP flows, ~200 packets each in 4 s. Required MV-FS-007 and `rtp_use_dtls=true` on the outbound leg. |

What the controller's dialplan must set on every leg it builds:
`rtp_secure_media=mandatory`, `rtp_use_dtls=true`,
`rtp_dtls_srtp_profiles=SRTP_AEAD_AES_256_GCM`, `media_timeout`,
`media_hold_timeout`. Baresip's own DTLS-SRTP profile order puts
`SRTP_AES128_CM_SHA1_80` first; the MVT build restricts it to
`SRTP_AEAD_AES_256_GCM` (an MVT-repository item), and the FreeSWITCH
variable above already prevents anything weaker being selected.

This is hop-by-hop protection of the SIP and media legs. It is not the
end-to-end model (D97): that is MLS/SFrame in the endpoints with a
key-blind relay, S2 after the G1 spike, and no FreeSWITCH change delivers
it.
