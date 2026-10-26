#!/usr/bin/env bash
# Build the TEST configuration for the hop-by-hop SRTP test from the installed production tree.
# Everything this does is what the installer or the controller would do on a real MVC, except the
# static test users/dialplan and the sqlite core database, which exist only because no controller
# and no PostgreSQL are running here. Nothing here goes into the fork.
set -euo pipefail
PREFIX=/opt/missionvoice/freeswitch
T=${MV_TEST_ROOT:-/home/claude/fsbuild}/test
PKI=${MV_TEST_ROOT:-/home/claude/fsbuild}/pki
rm -rf $T/conf && cp -r $PREFIX/etc/freeswitch $T/conf
ESL_PW=$(openssl rand -hex 16); echo "$ESL_PW" > $T/esl.pw
# installer substitutions
sed -i "s|__MVC_VPN_SUBNET__|127.0.0.0/8|" $T/conf/autoload_configs/acl.conf.xml
sed -i "s|__MVC_ESL_PASSWORD__|$ESL_PW|" $T/conf/autoload_configs/event_socket.conf.xml
sed -i "s|__MVC_LOOKUP_PASSWORD__|$(openssl rand -hex 12)|" $T/conf/autoload_configs/xml_curl.conf.xml
sed -i 's|mvc_sip_ip=$${local_ip_v4}|mvc_sip_ip=127.0.0.1|' $T/conf/vars.xml
# test-only: no controller, no PostgreSQL on this box
sed -i '/mod_xml_curl/d; /mod_pgsql/d' $T/conf/autoload_configs/modules.conf.xml
sed -i '/core-db-dsn/d' $T/conf/autoload_configs/switch.conf.xml
# loopback: sofia rejects 127.0.0.1 as an ext-* address (and inside the VPN they are never needed)
sed -i '/ext-sip-ip\|ext-rtp-ip/d' $T/conf/sip_profiles/missionvoice.xml
# certificates: FreeSWITCH's certs_dir is <conf>/tls unless -certs is given; the run script passes -certs
install -d $T/certs && cp $PKI/agent.pem $PKI/cafile.pem $PKI/dtls-srtp.pem $T/certs/
# static test users (what the controller would serve through xml_curl)
cat > $T/conf/directory/10-test.xml <<XML
<include>
  <domain name="127.0.0.1">
    <params><param name="dial-string" value="{sip_invite_domain=\${dialed_domain}}\${sofia_contact(*/\${dialed_user}@\${dialed_domain})}"/></params>
    <groups><group name="test"><users>
      <user id="mvt-a"><params><param name="password" value="test-a-$(openssl rand -hex 6)"/></params><variables><variable name="user_context" value="missionvoice"/></variables></user>
      <user id="mvt-b"><params><param name="password" value="test-b-$(openssl rand -hex 6)"/></params><variables><variable name="user_context" value="missionvoice"/></variables></user>
    </users></group></groups>
  </domain>
</include>
XML
# static test dialplan, sorted before 00-fail-closed.xml
cat > $T/conf/dialplan/00-0-test.xml <<'XML'
<include>
  <context name="missionvoice">
    <extension name="test-echo">
      <condition field="destination_number" expression="^echo$">
        <action application="set" data="rtp_secure_media=mandatory"/>
        <action application="set" data="rtp_dtls_srtp_profiles=SRTP_AEAD_AES_256_GCM"/>
        <action application="answer"/>
        <action application="echo"/>
      </condition>
    </extension>
    <extension name="test-user">
      <condition field="destination_number" expression="^(mvt-[ab])$">
        <action application="set" data="rtp_secure_media=mandatory"/>
        <action application="set" data="rtp_dtls_srtp_profiles=SRTP_AEAD_AES_256_GCM"/>
        <action application="export" data="rtp_secure_media=mandatory"/>
        <action application="export" data="rtp_use_dtls=true"/>
        <action application="export" data="rtp_dtls_srtp_profiles=SRTP_AEAD_AES_256_GCM"/>
        <action application="bridge" data="user/$1@127.0.0.1"/>
      </condition>
    </extension>
  </context>
</include>
XML
grep -o 'value="test-[ab]-[0-9a-f]*"' $T/conf/directory/10-test.xml | sed 's/value=//; s/"//g' > $T/sip.pw
echo CONF_OK
