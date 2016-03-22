# Setup OpenVPN Server
#
# Edit variables below and copy paste the script
# in a MikroTik terminal window.
#

:global CN [/system identity get name]
:global COUNTRY "UA"
:global STATE "KV"
:global LOC "Kyiv"
:global ORG ""
:global OU ""
:global USERNAME "user"
:global PASSWORD "password"


## generate CA certificate
/certificate
add name=ca-template country="$COUNTRY" state="$STATE" locality="$LOC" \
  organization="$ORG" unit="$OU" common-name="$CN" key-size=4096 \
  days-valid=3650 key-usage=crl-sign,key-cert-sign
sign ca-template ca-crl-host=127.0.0.1 name="$CN"
:if ( [/system resource get cpu-frequency] <= 600 ) do={:delay 30} \
  else={:delay 10}

## generate server certificate
/certificate
add name=server-template country="$COUNTRY" state="$STATE" locality="$LOC" \
  organization="$ORG" unit="$OU" common-name="server@$CN" key-size=4096 \
  days-valid=3650 key-usage=digital-signature,key-encipherment,tls-server
sign server-template ca="$CN" name="server@$CN"
:if ( [/system resource get cpu-frequency] <= 600 ) do={:delay 30} \
  else={:delay 10}

## create client template
/certificate
add name=client-template country="$COUNTRY" state="$STATE" locality="$LOC" \
  organization="$ORG" unit="$OU" common-name="client" \
  key-size=4096 days-valid=3650 key-usage=tls-client
:if ( [/system resource get cpu-frequency] <= 600 ) do={:delay 30} \
  else={:delay 10}

## create pool
/ip pool
add name=VPN-POOL ranges=192.168.252.2-192.168.252.254

## add profile
/ppp profile
add dns-server=192.168.252.1 local-address=192.168.252.1 name=VPN-PROFILE \
  remote-address=VPN-POOL use-encryption=yes

## setup server
/interface ovpn-server server
set auth=sha1 certificate="server@$CN" cipher=aes128,aes192,aes256 \
  default-profile=VPN-PROFILE enabled=yes require-client-certificate=yes

## add a firewall rule
/ip firewall filter
add chain=input dst-port=1194 protocol=tcp comment="Allow OpenVPN"

## add user
/ppp secret
add name=$USERNAME password=$PASSWORD profile=VPN-PROFILE service=ovpn

## generate client certificate
/certificate
add name=client-template-to-issue copy-from="client-template" \
  common-name="$USERNAME@$CN"
sign client-template-to-issue ca="$CN" name="$USERNAME@$CN"

## export the CA, client certificate and private key
/certificate
export-certificate "$CN" export-passphrase=""
export-certificate "$USERNAME@$CN" export-passphrase="$PASSWORD"

/