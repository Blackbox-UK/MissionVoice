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
| MV-FS-001 | `src/switch_rtp.c`: DTLS-SRTP negotiates `SRTP_AEAD_AES_256_GCM` (and AES-128-GCM, AES-128-CM as fallbacks), reads the selected profile, sizes keys from it, reports it in `rtp_has_crypto` and `CALL_SECURE`; channel variable `rtp_dtls_srtp_profiles` narrows the offer. Upstream hard-wires AES-128-CM/HMAC-SHA1-80. | D05, D49: AES-256 and SHA-2 on every leg; `mvc-key-management.md` section 2. | Written; **not yet built** (A14: build against the Spiral 1 pin). |
| MV-FS-002 | `build/modules.conf.missionvoice`: the module set. Twelve modules; `mod_signalwire`, `mod_enum`, `mod_httapi`, CDR modules, scripting and every codec but Opus are not built. | D46: no beacons (`mod_signalwire` connects to SignalWire's cloud); attack surface. | Written. |
| MV-FS-003 | `conf/missionvoice/`: the configuration tree. One SIP profile, TLS 1.3 only, mutual TLS, no clear-text listener, SRTP AEAD only, Opus CBR without DTX, ESL on loopback, no core dumps, no debug logging, directory and dialplan from the controller, static fallback that refuses everything. | E2EE analysis F3, F7, F8, section 1a; P25; D48. | Written. |
| MV-FS-004 | `blackbox/build.sh` and `blackbox/openssl-missionvoice.cnf`: reproducible build passing `--enable-openssl` through to the bundled libsrtp (without it there is no AES-GCM at all and SRTP is not on the OpenSSL provider), and the OpenSSL configuration the FreeSWITCH process runs under (TLS 1.3 suites and groups pinned; FIPS and TPM providers switched on when present). | E2EE analysis F2, F4. | Written; build to be run on the MVC host. |
| MV-FS-005 | `mod_sofia`: expose the verified TLS client certificate's subject and SHA-256 fingerprint as channel variables and pass them in the `mod_xml_curl` directory lookup. | E2EE analysis F3 identity-binding gap; D48. | Not started; S2. |
| MV-FS-006 | `src/switch_core_cert.c`: never generate a self-signed RSA-4096 `dtls-srtp.pem`; refuse to start DTLS without an installed device certificate. | F5; `mvc-key-management.md` rule 1. | Not started; S2. |

What FreeSWITCH keeps doing in Mission Voice, and for how long, is decided
by the G1 spike (handover v0.2 section 7.2): under D97 group media moves
to the key-blind relay, so `mod_conference` is interim.

## Upstream pin

The pinned upstream commit is recorded in `blackbox/UPSTREAM_PIN` and must
match what the Spiral 1 MVC was built from (A14). Until A14 is done the
file holds the commit this branch was cut from and says so.

## Building

See `blackbox/build.sh`. The build is reproducible: same pin, same module
list, same configure flags, same compiler, same output hash recorded in
the release manifest (P26).
