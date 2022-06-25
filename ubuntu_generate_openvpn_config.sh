#!/bin/sh

if (! command -v 'openvpn' > /dev/null) || [ ! -f /usr/share/easy-rsa/easyrsa ]; then
  sudo apt update
  sudo apt install easy-rsa openvpn
fi

# *COPIED* from below to make a tidy directory and generate the script there
OVPN_DIR="openvpn"
[ -d "$OVPN_DIR" ] && echo "ERROR: must start without an openvpn directory" && exit 1
mkdir -p $OVPN_DIR

# Main script is taken from here (but doesn't download its own easyrsa): https://openwrt.org/docs/guide-user/services/vpn/openvpn/automated_pc
# CURRENT WORKAROUNDS (Jun 2022):
# - Ubuntu is using older (2.4.7) openvpn than OpenWRT (2.5.3)
#   -> old rev of article is required to avoid unexpected genkey arguments (rev=1632708683)
# - The .rnd file bug seen in this version of EasyRSA/OpenVPN/OpenSSL is easiest to work-around by pre-creating the file
#   -> must be done after init-pki so add it to the first code block with sed:
#      sed -e "s/^easyrsa init-pki/easyrsa init-pki; openssl rand -writerand \$OVPN_PKI\/.rnd/")
# - The ${NL} code for generating server config didn't work, replace it with a regular newline in the 2nd code blob

# Other instruction refrences:
# https://openwrt.org/docs/guide-user/services/vpn/openvpn/server
# https://www.laroccx.com/posts/openvpn-openwrt/

URL="https://openwrt.org/_export/code/docs/guide-user/services/vpn/openvpn"
cat << EOF > $OVPN_DIR/tmp_ovpn.sh
OVPN_DIR="openvpn"
OVPN_PKI="\${OVPN_DIR}/pki"
OVPN_PORT="1194"
OVPN_PROTO="udp"
OVPN_POOL="10.0.0.0 255.255.255.0"
OVPN_DNS="\${OVPN_POOL%.* *}.1"
OVPN_DOMAIN="lan.ca.wto605.com"
OVPN_SERV="vpn.ca.wto605.com"
alias easyrsa="/usr/share/easy-rsa/easyrsa"
$(curl "${URL}/server?rev=1632708683&codeblock=1" \
| sed -e "s/^easyrsa init-pki/easyrsa init-pki; openssl rand -writerand \$OVPN_PKI\/.rnd/")
$(curl "${URL}/server?rev=1632708683&codeblock=3" \
| sed -e "/^\/etc\/init\.d\//d" \
| sed -e "s/\${NL}/\n/g" )
ls \${OVPN_DIR}/*.conf
EOF
sh ./$OVPN_DIR/tmp_ovpn.sh

echo 'IMPORTANT: server.conf is generated with a dynamic tun device, replace "dev tun" with "dev tunN" to assign a fixed number N'
